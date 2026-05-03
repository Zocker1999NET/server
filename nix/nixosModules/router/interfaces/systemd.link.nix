{ globalArg, ... }@interface:
let
  inherit (globalArg) lib options;
  ifCfg = interface.config;
  inherit (lib.modules) mkDefault;
  inherit (lib.options) literalExpression;
  systemdLinkOpts = options.systemd.network.links.type.nestedTypes.elemType.getSubOptions "";
in
{

  options = {

    matchConfig = lib.mkOption {
      description = ''
        Describes how this interface will be recognized.
        Works equivalent to {option}`systemd.network.links.<name>.matchConfig`.

        If omitted, the device will be expected to have the name of cfg.name,
        which is only sensible in case of virtual devices.
      '';
      type = systemdLinkOpts.matchConfig.type;
      default.OriginalName = ifCfg.name;
      defaultText = literalExpression ''
        { Name = ifCfg.name; }
      '';
      example = {
        PermanentMACAddress = "aa:bb:cc:dd:ee:ff";
      };
    };
    inherit (systemdLinkOpts) linkConfig;

  };

  config = {
    linkConfig = {
      Description = mkDefault ifCfg.description;
      MACAddressPolicy = lib.mkDefault "persistent";
      NamePolicy = ""; # -> use Name=
      Name = ifCfg.name;
      AlternativeNamesPolicy = "mac slot path onboard";
    };

  };

}
