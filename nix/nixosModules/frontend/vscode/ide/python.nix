{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.meta) getExe;
  inherit (lib.options) literalExpression mkOption mkPackageOption;
  cfg = config.python;
in
{

  # _class = "homeManager.vscodeProfile";

  options.python = {

    package = mkPackageOption pkgs "python3" { };

    extraPackages = mkOption {
      description = "Additional python packages to be installed in the default python environment for VSCode.";
      type = with types; functionTo (listOf package);
      default = _: [ ];
      example = literalExpression ''
        ps: with ps; [
          ansible-core
          proxmoxer
          requests
        ];
      '';
    };

    finalPackage = mkOption {
      description = ''
        The full python environment to be used by VSCode by default.

        Including {option}`python.extraPackages`.
      '';
      type = types.package;
      default = cfg.package.withPackages cfg.extraPackages;
      internal = true;
      readOnly = true;
    };

  };

  config = {

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
      "python.defaultInterpreterPath" = getExe cfg.finalPackage;

      "workbench.editorAssociations" = {
        "*.ipynb" = "jupyter-notebook";
      };
    };

  };

}
