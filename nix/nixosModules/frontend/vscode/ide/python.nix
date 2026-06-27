{
  lib,
  pkgs,
  ...
}:
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

    "black-formatter.path" = "${pkgs.black}/bin/black";

    "mypy-type-checker.importStrategy" = "fromEnvironment";
    "mypy.dmypyExecutable" = "${pkgs.mypy}/bin/dmypy";
    "mypy.runUsingActiveInterpreter" = true;
    "mypy.mypyExecutable" = "${pkgs.mypy}/bin/mypy";

    "python.analysis.autoImportCompletions" = true;
    "python.analysis.stubPath" = "./typings/";
    "python.defaultInterpreterPath" = lib.getExe pkgs.python3;
    "python.linting.enabled" = false;
    "python.showStartPage" = false;

    "workbench.editorAssociations" = {
      "*.ipynb" = "jupyter-notebook";
    };
  };

}
