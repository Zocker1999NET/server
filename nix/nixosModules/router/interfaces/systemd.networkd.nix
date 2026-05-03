{ globalArg, ... }@interfaces:
let
  inherit (globalArg) lib options;
  ifCfg = interfaces.config;
  netCfg = ifCfg.networkd;
  systemdNetworkdOpts = options.systemd.network.networks.type.nestedTypes.elemType.getSubOptions (
    lib.singleton ""
  );
in
{

  options.networkd = systemdNetworkdOpts;

  config = {
    assertions = [
      #
    ];

    networkd = {
      matchConfig.Name = ifCfg.name;
      # sane defaults

    };
  };

}
