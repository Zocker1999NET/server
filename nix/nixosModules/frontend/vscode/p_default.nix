{
  lib,
  pkgs,
  ...
}:
let
  mktPlc = pkgs.nix-vscode-extensions;
in
{

  # _class = "homeManager.vscodeProfile";

  extensions = with pkgs.vscode-extensions; [
    # cSpell:disable
    mktPlc.vscode-marketplace-release.mjmorales.generic-lsp-proxy
    mkhl.direnv
    # cSpell:enable
  ];
  userSettings = {

    "dev.containers.dockerComposePath" = "${lib.getExe pkgs.podman-compose}";
    "dev.containers.dockerPath" = "${lib.getExe pkgs.podman}";

  };
}
