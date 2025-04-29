{ globalArg, ... }@interface:
let
  inherit (globalArg) config lib;
  ifCfg = interface.config;
  wCfg = ifCfg.workarounds;
  inherit (builtins) elem;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) mkOption;
  systemdVersion = lib.toIntBase10 (lib.versions.major config.systemd.package.version);
in
{

  options.workarounds = {
    # options here supply additional information
    # which are only required for determining if a workaround is required
    # SHOULD BE without default & so required when used
    dhcpv6PrefixDelegationWithoutAddress = mkOption {
      description = ''
        Describes whether the DHCPv6 server on this network (provided by the ISP)
        is only providing prefix delegations (IA_PD)
        while not providing non-temporary addresses (IA_NA).

        As of now, this information is used for following workarounds:
        - https://github.com/systemd/systemd/issues/31349#issuecomment-1949165385 (systemd <= 255)
      '';
      type = lib.types.bool;
    };
  };

  config = mkMerge [
    (mkIf (
      systemdVersion <= 255
      && elem "dhcp-pd" ifCfg.routing.ipv6DownstreamModes
      && wCfg.dhcpv6PrefixDelegationWithoutAddress
    ) { networkd.dhcpV6Config.UseAddress = false; })
  ];

}
