# attempts to disable all special network configs the test driver supplies
# so that the systems actually "need to do everything on their own"
# useful for large scale networking tests involving realistic networks with DHCP, SLAAC, …

{ lib, ... }:
let
  inherit (lib.modules) mkForce;
in
{
  _class = "nixosTest";
  defaults = {
    networking = {
      # test driver would supply /etc/hosts entries so machines can find each other
      extraHosts = mkForce "";
      # test driver would setup all nodes with static IPs
      interfaces = mkForce { };
    };
  };
}
