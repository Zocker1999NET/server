{ globalArg, ... }@interface:
let
  inherit (globalArg) lib libBNet;
  ifCfg = interface.config;
  ifOpts = interface.options;
  fwCfg = ifCfg.firewall;
  pingCfg = fwCfg.pingable;
  expCfg = fwCfg.exposed;
  # helpers
  inherit (builtins) filter;
  inherit (lib.lists) singleton;
  inherit (libBNet.options) mkSubmoduleListExtension;
  inherit (lib.trivial) pipe;
in
{

  options.firewall = {
    exposed = {
      fullDevices = mkSubmoduleListExtension [
        lib.optionSets.pingableRule
        {
          options.pingable = lib.mkOption {
            default = pingCfg.fullDevices;
            defaultText = lib.literalExpression "ifCfg.pingable.fullDevices";
          };
        }
      ];
      devicePorts = mkSubmoduleListExtension [
        lib.optionSets.pingableRule
        {
          options.pingable = lib.mkOption {
            default = pingCfg.devicePorts;
            defaultText = lib.literalExpression "ifCfg.pingable.devicePorts";
          };
        }
      ];
    };

    pingable = {
      fullDevices = lib.mkDisableOption "pingability of devices fully exposed";
      devicePorts = lib.mkDisableOption "pingability of devices with some exposed ports by default (can be overwritten per port rule)";
    };
  };

  config.firewall.pingable.devices = pipe (expCfg.fullDevices ++ expCfg.devicePorts) [
    (filter (x: x.pingable))
    (map (x: x._cloneFor ifOpts.firewall.pingable.devices // { devices = singleton x.device; }))
  ];

}
