{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  routCfg = ifCfg.routing;
  inherit (builtins) attrNames elem mapAttrs;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) flatten singleton unique;
  inherit (lib.modules) mkDefault mkIf mkMerge;
  inherit (lib.network) mergeIPv6IfId;
  inherit (lib.trivial) pipe;
  mkMergeFlat = list: mkMerge (flatten list);
  # TODO upstream
  mkIfElse =
    cond: valTrue: valFalse:
    mkMerge [
      (mkIf cond valTrue)
      (mkIf (!cond) valFalse)
    ];
  # values
  ifIdToken = mkIfElse (routCfg.ipv6InterfaceId != null) "static:${routCfg.ipv6InterfaceId}" "eui64";
  modeOpts = {

    "custom" = { };

    "dhcp-pd" = {
      networkd = {
        linkConfig.RequiredForOnline = mkDefault false; # we are providing internet
        address = singleton (
          mkIf (routCfg.ipv6InterfaceId != null) (mergeIPv6IfId "fe80::/64" routCfg.ipv6InterfaceId)
        );
        networkConfig = {
          IPv6AcceptRA = false;
          IPv6SendRA = true;
          DHCPPrefixDelegation = true;
        };
        ipv6SendRAConfig = {
          # TODO until https://github.com/systemd/systemd/issues/29651 is fixed:
          RouterLifetimeSec = mkDefault (5 * 60); # set so low in case of a prefix renewal
          UplinkInterface = ":none"; # TODO rethink
          DNS = "_link_local";
          Domains = mkDefault routCfg.domain;
        };
        ipv6Prefixes = mkIf (routCfg.ipv6ULAPrefix != null) (singleton {
          Prefix = routCfg.ipv6ULAPrefix;
          Assign = true;
          Token = ifIdToken;
        });
        dhcpPrefixDelegationConfig = {
          UplinkInterface = routCfg.upstream;
          SubnetId = toString routCfg.upstreamIdx;
          Announce = true;
          Assign = mkDefault true;
          Token = ifIdToken;
          ManageTemporaryAddress = false;
        };
      };
    };

    # TODO "prefix-nat"

  };
  # use sparsly, as needs to be compatible with most other settings
  upstreamModeOpts = (mapAttrs (_: _: { }) modeOpts) // {

    "dhcp-pd" = {
      assertions = singleton {
        # TODO revisit if even required
        assertion = elem (ifCfg.networkd.networkConfig.DHCP or "yes") [
          "yes"
          "ipv6"
        ];
        message = "DHCPv6 must be enabled on upstream for working prefix delegation";
      };
      networkd.dhcpV6Config = {
        PrefixDelegationHint = "::/60"; # TODO make configurable
        # TODO until https://github.com/systemd/systemd/issues/34299
        WithoutRA = "solicit";
      };
    };

  };
in
assert attrNames modeOpts == attrNames upstreamModeOpts;
{

  options.routing = {

    ipv6Mode = lib.mkOption {
      description = ''
        Describes the logical behavior of IPv6 addressing for clients
        and routing from/to the upstream interface.

        You can ignore this setting & configure everything yourself,
        this is just to provide common configurations more easily.
      '';
      type = lib.types.enum (attrNames modeOpts);
      default = "custom";
      example = "dhcp-pd";
    };

    ipv6DownstreamModes = lib.mkOption {
      internal = true;
      readOnly = true;
      description = "Corresponding setting to ipv6Mode for upstream interfaces, reflecting values set on downstream interfaces";
      type = with lib.types; listOf (enum (attrNames modeOpts));
      default = pipe routCfg.downstreams [
        (map (x: x.routing.ipv6Mode))
        unique
      ];
    };

  };

  config = mkMergeFlat [
    (mapAttrsToList (mode: opts: mkIf (routCfg.ipv6Mode == mode) opts) modeOpts)
    (mapAttrsToList (mode: opts: mkIf (elem mode routCfg.ipv6DownstreamModes) opts) upstreamModeOpts)
  ];

}
