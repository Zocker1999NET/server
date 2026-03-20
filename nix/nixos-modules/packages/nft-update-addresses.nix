{
  config,
  lib,
  pkgs,
  ...
}:
let
  servName = "nft-update-addresses";
  cfg = config.services.${servName};
  settingsFormat = pkgs.formats.json { };
  mkDisableOption = desc: lib.mkEnableOption desc // { default = true; };
  # JSON schema for validation
  schemaFile = pkgs.writeTextFile {
    name = "config.schema.json";
    text = builtins.readFile ../../../update-addresses/config.schema.json;
  };
  # output options values
  configFile = pkgs.writeTextFile {
    name = "${servName}.json";
    text = builtins.toJSON cfg.settings; # TODO can otherwise not easily check the file for errors
    checkPhase = ''
      ${lib.getExe pkgs.jsonschema} ${schemaFile} "$out"
      ${lib.getExe cfg.package} --check-config --config-file "$out"
    '';
  };
  staticDefs = builtins.readFile (
    pkgs.runCommandLocal "${servName}.nftables" { } ''
      ${lib.getExe cfg.package} --output-set-definitions --config-file ${configFile} > $out
    ''
  );
in
{

  options.services.${servName} = {

    enable = lib.mkEnableOption "${servName} service";

    package = lib.mkPackageOption pkgs (lib.singleton servName) { };

    settings = lib.mkOption {
      # TODO link to docu
      description = "Configuration for ${servName}";
      type = settingsFormat.type;
      default = {
        nftTable = "nixos-fw";
      };
      example.interfaces = {
        wan0 = { };
        lan0.ports.tcp = {
          exposed = [
            {
              dest = "aa:bb:cc:dd:ee:ff";
              port = 80;
            }
            {
              dest = "aa:bb:cc:00:11:22";
              port = 80;
            }
          ];
          forwarded = [
            {
              dest = "aabb-ccdd-eeff";
              lanPort = 80;
              wanPort = 80;
            }
            {
              dest = "aa.bbcc.0011.22";
              lanPort = 80;
              wanPort = 8080;
            }
          ];
        };
      };
    };

    includeStaticDefinitions = mkDisableOption "inclusion of static definitions from {option}`services.${servName}.nftablesStaticDefinitions` into the nftables config";

    configurationFile = lib.mkOption {
      description = "Path to configuration file used by ${servName}.";
      type = lib.types.path; # needs to be available at build time
      readOnly = true;
      default = configFile;
      defaultText = lib.literalExpression "# content as generated from config.services.${servName}.settings";
    };

    nftablesStaticDefinitions = lib.mkOption {
      description = ''
        Static definitions provided by ${servName} when called with given configuration.

        When {option}`services.${servName}.includeStaticDefinitions (which is default),
        these will be already included in your nftables setup.
        Otherwise, you can use the value of this output option as you prefer.
      '';
      readOnly = true;
      default = staticDefs;
      defaultText = lib.literalExpression "# as provided by ${servName}";
    };

  };

  config = lib.mkIf cfg.enable {

    assertions = [
      {
        assertion = cfg.enable -> config.networking.nftables.enable;
        message = "${servName} requires nftables to be configured";
      }
      # TODO assert for port duplications
    ];

    networking.nftables.tables.${cfg.settings.nftTable}.content =
      lib.mkIf cfg.includeStaticDefinitions staticDefs;

    systemd.services.${servName} = {
      description = "IPv6 prefix rules updater for nftables";
      after = [
        "nftables.service"
        "network.target"
      ];
      partOf = lib.singleton "nftables.service";
      requisite = lib.singleton "nftables.service";
      wantedBy = lib.singleton "multi-user.target";
      upheldBy = lib.singleton "systemd-networkd.service";
      unitConfig.ReloadPropagatedFrom = lib.singleton "nftables.service";
      restartIfChanged = true;
      restartTriggers = config.systemd.services.nftables.restartTriggers;
      serviceConfig = {
        # Service
        Type = "notify-reload";
        ExecStart = lib.singleton "${lib.getExe cfg.package} ${
          lib.cli.toGNUCommandLineShell { } {
            config-file = configFile;
            ip-command = "${pkgs.iproute2}/bin/ip";
            nft-command = lib.getExe pkgs.nftables;
          }
        }";
        RestartSec = "250ms";
        RestartSteps = 3;
        RestartMaxDelaySec = "3s";
        TimeoutSec = "10s";
        Restart = "always";
        NotifyAccess = "main";
        # Paths
        ProtectProc = "noaccess";
        ProcSubset = "pid";
        CapabilityBoundingSet = [
          "CAP_BPF" # nft is compiled to bpf
          "CAP_IPC_LOCK" # ?
          "CAP_KILL" # ?
          "CAP_NET_ADMIN"
        ];
        # Security
        NoNewPrivileges = true;
        # Process
        KeyringMode = "private";
        OOMScoreAdjust = 10;
        # Scheduling
        Nice = -2;
        CPUSchedulingPolicy = "fifo";
        # Sandboxing
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        PrivateNetwork = false; # breaks nftables
        PrivateIPC = true;
        PrivateUsers = false; # breaks nftables
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true; # are already loaded
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        #RestrictAddressFamilies = [
        #  # ?
        #  "AF_INET"
        #  "AF_INET6"
        #  #"AF_NETLINK"
        #];
        RestrictNamespaces = true;
        RestrictSUIDSGID = true;
        #SystemCallFilter = "@basic-io @ipc @network-io @signal @timer" # definitly will break that
        #SystemCallLog = "~"; # for debugging; should lock all system calls made
        # Resource Control
        CPUQuota = "50%";
        # TODO test to gather real values
        MemoryLow = "8M";
        MemoryHigh = "32M";
        MemoryMax = "128M";
      };
    };

  };

}
