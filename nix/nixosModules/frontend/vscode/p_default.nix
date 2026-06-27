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
    jbockle.jbockle-format-files
    mktPlc.vscode-marketplace-release.mjmorales.generic-lsp-proxy
    mkhl.direnv
    # cSpell:enable
  ];
  userSettings = {

    "dev.containers.dockerComposePath" = "${lib.getExe pkgs.podman-compose}";
    "dev.containers.dockerPath" = "${lib.getExe pkgs.podman}";

    "files.associations" = {
      "*.makefile" = "makefile";
    };
    "files.exclude" = {
      # cSpell:disable
      "**/.classpath" = true;
      "**/.factorypath" = true;
      "**/.mypy_cache" = true;
      "**/.project" = true;
      "**/.pytest_cache" = true;
      "**/.settings" = true;
      "**/__pycache__" = true;
      "**/venv" = true;
      # cSpell:enable
    };
    "files.watcherExclude" = {
      "**/venv" = true;
    };

    "html.format.enable" = false;

    "json.format.enable" = true;
    "json.format.keepLines" = true;

    # here just in case
    "redhat.telemetry.enabled" = false;

    "telemetry.telemetryLevel" = "off";

    "typescript.updateImportsOnFileMove.enabled" = "always";

  };
}
