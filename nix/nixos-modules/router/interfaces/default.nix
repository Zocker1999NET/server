{ globalArg, name, ... }@interface:
let
  inherit (globalArg) lib options;
  ifCfg = interface.config;
  ifOpts = interface.options;
in
{

  imports = [
    # directories
    ./dstnat
    ./firewall
    ./nftables
    ./routing
    # files
    ./devices.nix
    ./groups.nix
    ./kind.nix
    ./nft-update-addresses.nix
    ./references.nix
    ./srcnat.nix
    ./systemd.link.nix
    ./systemd.networkd.nix
    ./workarounds.nix
  ];

  options = {
    # TODO (important) evaluate
    assertions = options.assertions;
    warnings = options.warnings;

    enable = lib.mkDisableOption "Configure rules for this interface";
    name = lib.mkOption {
      description = ''
        Name for this interface.

        Interface will be renamed to this if cfg.matchConfig is also set.
        Otherwise, the device must already be named like this,
        which is only sensible in case of 3rd-party services like VPNs.
      '';
      type = lib.types.ifName;
      default = name;
    };
    description = lib.mkOption {
      description = "Descriptive, human-readable name for that device";
      type = lib.types.str;
      default = "${ifCfg.name} of kind ${ifCfg.kind}";
      example = lib.literalExpression ''"''${ifCfg.name} of kind ''${ifCfg.kind}"'';
    };

    ifOptions = lib.mkOption {
      description = "easiest way to make options value (with definitions loaded!) accessible to other interfaces";
      internal = true;
      default = ifOpts;
    };
  };

}
