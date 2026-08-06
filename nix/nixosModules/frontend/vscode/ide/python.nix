{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
in
{

  # _class = "homeManager.vscodeProfile";

  extensions = with pkgs.vscode-extensions; [
    charliermarsh.ruff
    ms-python.debugpy
    ms-python.vscode-python-envs # only wanted for redhat.ansible
    matangover.mypy
    # TODO (feature) maybe add isort, https://github.com/microsoft/vscode-isort, in nixpkgs
    # pylance does not work with VSCodium due to MSFT
    ms-pyright.pyright
    ms-python.python
  ];

  userSettings = {
    "[python]" = {
      "editor.defaultFormatter" = "charliermarsh.ruff";
    };

    "mypy.dmypyExecutable" = "${pkgs.mypy}/bin/dmypy";
    "mypy.runUsingActiveInterpreter" = false; # use mypy/dmypy from nixpkgs (otherwise mypy is needed to be installed in the used venv)
    "mypy.mypyExecutable" = "${pkgs.mypy}/bin/mypy";

    "python.analysis.autoImportCompletions" = true;
    "python.analysis.stubPath" = "./typings/";
    "python.defaultInterpreterPath" = lib.getExe pkgs.python3;

    "workbench.editorAssociations" = {
      "*.ipynb" = "jupyter-notebook";
    };
  };

}
