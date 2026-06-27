{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.meta) getExe;
in
{

  # _class = "homeManager.vscodeProfile";

  # TODO this still needs to be fully configured
  # TODO make dependent on osConfig podman enabled

  userSettings = {
    "dev.containers.dockerComposePath" = getExe pkgs.podman-compose;
    "dev.containers.dockerPath" = getExe pkgs.podman;
  };

}
