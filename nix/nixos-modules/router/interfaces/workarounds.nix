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
