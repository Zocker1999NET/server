# prevents test nodes to have accidental access to the network / internet

# - important for tests executed interactively because those are not "protected" by the Nix sandbox themselves
# - implemented by effectively disabling the backdoor interface (which is not )

# TODO (if even possible): add NixOS test for this

{
  lib,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.attrsets) mapAttrs' nameValuePair;
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) mkOption;
in
{
  _class = "nixosTest";

  defaults =
    {
      config,
      ...
    }:
    let
      inherit (config.networking) useNetworkd;
      inherit (config.testing) backdoorInterface;
      prefixAttrs = prefix: mapAttrs' (name: val: nameValuePair "${prefix}${name}" val);
    in
    {

      options.testing = {
        backdoorInterface = mkOption {
          description = "Name of backdoor interface added by the test driver.";
          type = types.str;
          default = "eth0";
          internal = true;
        };
      };

      config = mkMerge [

        # classical networking
        (mkIf (!useNetworkd) {
          warnings = singleton "nixosTest module networkingPreventLeaks for classical networking not yet tested!";
          boot.kernel.sysctl = prefixAttrs "net.ipv6.conf.${backdoorInterface}." {
            # disabling accept_ra can be fatal because some parameters in a RA are important, e.g. MTU
            accept_ra_defrtr = false; # ignore default router
            accept_ra_pinfo = false; # ignore prefix info
            addr_gen_mode = 1; # do not generate link-local address
            autoconf = false; # do not configure IPs
          };
          networking.interfaces.${backdoorInterface} = {
            useDHCP = false;
          };
        })

        # systemd-networkd
        (mkIf useNetworkd {
          systemd.network = {
            networks."00-20-disable-backdoor-interface" = {
              matchConfig.Name = backdoorInterface;
              linkConfig.Unmanaged = true;
            };
            wait-online.ignoredInterfaces = singleton backdoorInterface;
          };
        })
      ];

    };

}
