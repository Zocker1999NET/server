{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins)
    concatStringsSep
    toJSON
    ;
  inherit (lib) types;
  inherit (lib.modules) mkIf;
  inherit (lib.options)
    mkEnableOption
    mkOption
    mkPackageOption
    ;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  inherit (lib.strings) escapeShellArg;
  inherit (lib.trivial) flip;

  servName = "dns-dynamic-primary-reflector";
  cfg = config.services.${servName};
  settingsFormat = pkgs.formats.json { };
  configFile = pkgs.writeTextFile {
    name = "${servName}.json";
    checkPhase = ''
      ${pkgs.jq}/bin/jq -e . "$out" > /dev/null
    '';
    text = toJSON cfg.settings;
  };

  envArgs = flip mapAttrsToList cfg.envVarFiles (
    name: file: ''DDPR:${escapeShellArg name}="$(<${escapeShellArg file})"''
  );
in
{

  _class = "nixos";

  options.services.${servName} = {

    enable = mkEnableOption "${servName} service";

    package = mkPackageOption pkgs (lib.singleton servName) { };

    settings = mkOption {
      description = "Configuration for ${servName}.";
      type = types.submodule {
        freeformType = settingsFormat.type;
        options = {
          hetzner_domains = mkOption {
            description = "Hetzner DNS zone names whose primary nameservers shall be updated.";
            type = with types; listOf str;
          };
          ip_sources = mkOption {
            description = ''
              Layered IP source definitions, queried for a unique consensus.

              Each layer is a list of sources.
              The layers are queried in a randomized order,
              until a unique consensus among the answers is reached.
            '';
            # actual structure is checked at runtime by the program
            type = settingsFormat.type;
            example = [
              [
                "https://icanhazip.com"
                {
                  class = "ipv4";
                  url = "https://checkip.amazonaws.com/";
                }
              ]
              [
                "https://wtfismyip.com/text"
                {
                  class = "ipv6";
                  url = "https://v6.ident.me";
                }
              ]
            ];
          };
          logging = mkOption {
            description = "Optional logging configuration.";
            type = types.nullOr (
              types.submodule {
                options.ntfy.url = mkOption {
                  description = "ntfy topic URL to publish warnings & errors to.";
                  type = types.str;
                };
              }
            );
            default = null;
          };
        };
      };
    };

    envVarFiles = mkOption {
      description = ''
        Configuration values injected via environment variables from files.

        Each attribute name is a configuration path,
        the same which are supported in {option}`services.${servName}.settings`,
        with segments separated by `:` (without the `DDPR:` prefix),
        and its value is a file whose tail-trimmed content
        is assigned to that config path.
      '';
      type = with types; attrsOf path;
      example = {
        HETZNER_API_KEY = "/run/secrets/hetzner";
        "LOGGING:NTFY:URL" = "/run/secrets/ntfy-url";
      };
    };

    configurationFile = mkOption {
      description = "Path to configuration file used by ${servName}.";
      type = types.path;
      readOnly = true;
      default = configFile;
      defaultText = lib.literalExpression "# content as generated from config.services.${servName}.settings";
    };

  };

  config = mkIf cfg.enable {
    systemd.services.${servName} = {
      description = "DNS primary nameserver IP reflector for Hetzner DNS";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      startAt = "*:0/5";
      path = singleton pkgs.curl;
      # var names containing `:` are no valid shell identifiers -> using `env`
      script = ''
        exec env ${concatStringsSep " " envArgs} \
          ${getExe cfg.package} \
          --config ${configFile} \
          --state-dir "$STATE_DIRECTORY"
      '';
      serviceConfig = {
        Type = "oneshot";
        # avoids firing at exact clock minutes, spreading load & fingerprinting
        RandomizedDelaySec = "1min";
        StateDirectory = servName;
        # Security
        NoNewPrivileges = true;
        ProtectProc = "noaccess";
        ProcSubset = "pid";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        PrivateIPC = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        # Resource Control
        CPUQuota = "10%";
        MemoryLow = "16M";
        MemoryHigh = "64M";
        MemoryMax = "128M";
      };
    };

  };

}
