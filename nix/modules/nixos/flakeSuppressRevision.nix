# useful for configurations & esp. nixosTests
# which should not change despite unrelated changes to the overall flake

{
  lib,
  ...
}:
let
  inherit (lib.modules) mkForce;
in
{
  _class = "nixos";
  config = {
    # do not just set null, rather set to recognizable string in case it is used unexpectedly
    system.configurationRevision = mkForce "flake.rev-suppressed";
  };
}
