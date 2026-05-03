{ globalArg, ... }@interface:
let
  inherit (globalArg) config lib;
  ifCfg = interface.config;
  wCfg = ifCfg.workarounds;

  inherit (builtins)
    concatStringsSep
    elem
    filter
    mapAttrs
    ;
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) flip pipe;
  systemdVersion = lib.toIntBase10 (lib.versions.major config.systemd.package.version);

  # options here supply additional information
  # which are only required for determining if a workaround is required
  # SHOULD BE without default -> users are required to fill them in when relevant
  workaroundInfos = {
    dhcpv6IsAvmFritzBox = {
      description = ''
        Describes whether the DHCPv6 server on this network
        is a AVM FRITZ!Box device.
        This info is most often required because some FRITZ!Box devices are known to violate RFC 8415 (DHCPv6).
        In case you do not know or assume such a device operates as your DHCPv6 server,
        you can just set this to `false`.
      '';
      type = lib.types.bool;
      # no default because FRITZ!Boxes are quite common in European home/SOHO setups
    };
    dhcpv6PrefixDelegationWithoutAddress = {
      description = ''
        Describes whether the DHCPv6 server on this network (provided by the ISP)
        is only providing prefix delegations (IA_PD)
        while not providing non-temporary addresses (IA_NA).
      '';
      type = lib.types.bool;
    };
  };

  # "requiredInfo" is only used to build description of info options
  workarounds = [
    {
      description = ''
        https://github.com/systemd/systemd/issues/31349#issuecomment-1949165385 (systemd <= 255)
      '';
      requiredInfo = singleton "dhcpv6PrefixDelegationWithoutAddress";
      condition = (
        systemdVersion <= 255
        && elem "dhcp-pd" ifCfg.routing.ipv6DownstreamModes
        && wCfg.dhcpv6PrefixDelegationWithoutAddress
      );
      action.networkd.dhcpV6Config.UseAddress = false;
    }
    {
      description = ''
        RFC 8415 implies by its MUST requirements that a router must handle all IA_* requests independently.
        In case of a FRITZ!Box 6590 running FRITZ!OS 7.57,
        when receiving a request message containing a IA_NA and a IA_PD request,
        it may only answer with the status code NoAddr
        As of now, this information is used for following workarounds:Avail because IA_NA is disabled,
        even through IA_PD is enabled (and would be assigned as expected in case it was requested alone).
        So in case of a FRITZ!Box, DHCPv6 clients should not request for an IA_NA unless required.
      '';
      requiredInfo = [
        "dhcpv6IsAvmFritzBox"
        "dhcpv6PrefixDelegationWithoutAddress"
      ];
      condition = (
        elem "dhcp-pd" ifCfg.routing.ipv6DownstreamModes
        && wCfg.dhcpv6IsAvmFritzBox
        && wCfg.dhcpv6PrefixDelegationWithoutAddress
      );
      action.networkd.dhcpV6Config.UseAddress = false;
    }
  ];

in
{

  options.workarounds = flip mapAttrs workaroundInfos (
    n: i:
    mkOption (
      i
      // {
        description = ''
          ${i.description}

          In general, these workaround infos are required to be known at build time
          because the used software cannot dynamically detect if these workarounds are required or not.

          As of now, this information is used for following workarounds:

          - ${concatStringsSep "\n- " (filter (w: elem n w.requiredInfo) workarounds)}
        '';
      }
    )
  );

  config = pipe workarounds [
    (map (w: mkIf w.condition w.action))
    mkMerge
  ];

}
