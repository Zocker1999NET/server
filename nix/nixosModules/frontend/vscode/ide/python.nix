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
    ms-python.black-formatter
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
      "editor.defaultFormatter" = "ms-python.black-formatter";
    };

    "black-formatter.path" = singleton "${pkgs.black}/bin/black";

    "mypy.dmypyExecutable" = "${pkgs.mypy}/bin/dmypy";
    "mypy.runUsingActiveInterpreter" = true;
    "mypy.mypyExecutable" = "${pkgs.mypy}/bin/mypy";

    "python.analysis.autoImportCompletions" = true;
    "python.analysis.stubPath" = "./typings/";
    "python.defaultInterpreterPath" = lib.getExe pkgs.python3;

    "workbench.editorAssociations" = {
      "*.ipynb" = "jupyter-notebook";
    };
  };

}
