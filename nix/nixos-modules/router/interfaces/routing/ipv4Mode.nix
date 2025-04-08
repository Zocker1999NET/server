{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  routCfg = ifCfg.routing;
  inherit (builtins) attrNames;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) flatten singleton;
  inherit (lib.modules) mkDefault mkIf mkMerge;
  mkMergeFlat = list: mkMerge (flatten list);
  modeOpts = {

    "custom" = { };

    "nat+dhcp" = {
      assertions = [
        {
          assertion = !isNull routCfg.ipv4Address;
          message = ".routing.ipv4Address required for DHCP server";
        }
      ];
      networkd = {
        linkConfig.RequiredForOnline = mkDefault false; # we are providing internet
        networkConfig = {
          DHCPServer = true;
        };
        dhcpServerConfig = {
          ServerAddress = routCfg.ipv4Address; # also assigns address to interface
          UplinkInterface = ":none"; # TODO rethink
          DNS = mkDefault "_server_address"; # TODO conditionally
          SendOption = singleton "15:string:${routCfg.domain}";
          EmitNTP = mkDefault false;
          EmitSIP = mkDefault false;
          EmitPOP3 = mkDefault false;
          EmitSMTP = mkDefault false;
          EmitLPR = mkDefault false;
        };
      };
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
