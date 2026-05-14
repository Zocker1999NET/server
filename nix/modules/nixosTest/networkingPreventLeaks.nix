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
  inherit (lib.modules) mkMerge;
  inherit (lib.lists) singleton;
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
      inherit (config.testing) backdoorInterface;
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

      # we disable the backdoor interface for both classical & networkd, just in case
      config = mkMerge [
        # classical networking
        {
          # TODO implement
        }
        # systemd-networkd
        {
          systemd.network = {
            networks."00-20-disable-backdoor-interface" = {
              matchConfig.Name = backdoorInterface;
              linkConfig.Unmanaged = true;
            };
            wait-online.ignoredInterfaces = singleton backdoorInterface;
          };
        }
      ];

    };

}
