{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  routCfg = ifCfg.routing;
  inherit (builtins) attrNames;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) flatten singleton;
  inherit (lib.modules) mkIf mkMerge;
  mkMergeFlat = list: mkMerge (flatten list);
  modeOpts = {

    "custom" = { };

    "nat+dhcp" = {
      services.dhcp.enable = true;
      srcnat.ipv4.enableFor = singleton routCfg.upstream;
    };

    # TODO "prefix-nat"

    # TODO "464xlat"

  };
in
{

  options.routing = {

    ipv4Mode = lib.mkOption {
      description = ''
        Describes the logical behavior of IPv4 addressing for clients
        and routing from/to the upstream interface.

        You can ignore this setting & configure everything yourself,
        this is just to provide common configurations more easily.
      '';
      type = lib.types.enum (attrNames modeOpts);
      default = "custom";
      example = "nat+dhcp";
    };

  };

  config = mkMergeFlat [
    {

    }
    (mapAttrsToList (mode: opts: mkIf (routCfg.ipv4Mode == mode) opts) modeOpts)
  ];

}
