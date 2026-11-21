{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) toJSON;
  inherit (lib) types;
  inherit (lib.options)
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    ;
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  inherit (lib.strings) escapeShellArg;

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

    apiKeyFile = mkOption {
      description = "File containing the Hetzner DNS API token.";
      type = types.path;
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
      # env var names containing `:` are no valid shell identifiers
      # hence the key is passed to the program by `env` directly
      script = ''
        exec env "DDPR:HETZNER_API_KEY=$(<${escapeShellArg cfg.apiKeyFile})" \
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
