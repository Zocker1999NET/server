# parts my frontend home-manager module only applicable to machines used for developing stuff (currently all)
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

{

  home.packages = with pkgs; [
    # editors
    neovim
    # general tools
    gnumake
    just
    # nix dev
    nix-output-monitor
  ];

  programs = {

    vscode = {
      enable = true;
      keybindingsNext = {
        # tabbing in *visually visible* order
        "ctrl+tab" = [
          {
            command = "-workbench.action.quickOpenNavigateNextInEditorPicker";
            when = "inEditorsPicker && inQuickOpen";
          }
          "-workbench.action.quickOpenPreviousRecentlyUsedEditorInGroup"
          "workbench.action.nextEditor"
        ];
        "ctrl+shift+tab" = [
          {
            command = "-workbench.action.quickOpenNavigatePreviousInEditorPicker";
            when = "inEditorsPicker && inQuickOpen";
          }
          "-workbench.action.quickOpenLeastRecentlyUsedEditorInGroup"
          "workbench.action.previousEditor"
        ];
        # disable overlappings from vim plugin
        "ctrl+p" = lib.singleton {
          command = "-extension.vim_ctrl+p";
          when = "editorTextFocus && vim.active && vim.use<C-p> && !inDebugRepl || vim.active && vim.use<C-p> && !inDebugRepl && vim.mode == 'CommandlineInProgress' || vim.active && vim.use<C-p> && !inDebugRepl && vim.mode == 'SearchInProgressMode'";
        };
      };
      mutableExtensionsDir = false;
      package = pkgs.vscodium;
      profiles.default = {
        enableExtensionUpdateCheck = config.programs.vscode.mutableExtensionsDir;
        enableUpdateCheck = false;
        extensions = with pkgs.vscode-extensions; [
          # general
          vscodevim.vim
          # AI assistant
          rooveterinaryinc.roo-cline
          # IDE: LaTeX
          james-yu.latex-workshop
          # IDE: Nix
          jnoortheen.nix-ide
          # IDE: Python
          ms-python.black-formatter
          ms-python.debugpy
          matangover.mypy
          # TODO (feature) maybe add isort, https://github.com/microsoft/vscode-isort, in nixpkgs
          # pylance does not work with VSCodium due to MSFT
          ms-pyright.pyright
          ms-python.python
        ];
        userSettings = {

          "[nix]" = {
            "editor.tabSize" = 2;
          };

          "[python]" = {
            "editor.defaultFormatter" = "ms-python.black-formatter";
          };

          "ansible.ansibleLint.path" = "${lib.getExe pkgs.ansible-lint}";

          "dev.containers.dockerComposePath" = "${lib.getExe pkgs.podman-compose}";
          "dev.containers.dockerPath" = "${lib.getExe pkgs.podman}";

          "diffEditor.ignoreTrimWhitespace" = false;
          "diffEditor.renderSideBySide" = false;

          "editor.cursorBlinking" = "solid";
          "editor.fontFamily" =
            "'FiraCode Nerd Font', 'Fira Code','Droid Sans Mono', 'monospace', monospace, 'Droid Sans Fallback'";
          "editor.fontLigatures" = true;
          "editor.formatOnSave" = true;
          "editor.largeFileOptimizations" = false;
          "editor.minimap.enabled" = false;
          "editor.renderWhitespace" = "boundary";
          "editor.suggest.localityBonus" = true;
          "editor.suggestSelection" = "recentlyUsedByPrefix";
          "editor.wordWrap" = "on";

          "explorer.compactFolders" = true;
          "explorer.confirmDelete" = false;

          "extensions.ignoreRecommendations" = true;

          "files.associations" = {
            "*.makefile" = "makefile";
          };
          "files.autoSave" = "onFocusChange";
          "files.exclude" = {
            "**/.classpath" = true;
            "**/.factorypath" = true;
            "**/.mypy_cache" = true;
            "**/.project" = true;
            "**/.pytest_cache" = true;
            "**/.settings" = true;
            "**/__pycache__" = true;
            "**/venv" = true;
          };
          "files.insertFinalNewline" = true;
          "files.trimTrailingWhitespace" = true;
          "files.watcherExclude" = {
            "**/venv" = true;
          };

          "git.autofetch" = true;
          "git.confirmSync" = false;
          "git.enableSmartCommit" = true;

          "html.format.enable" = false;

          "json.format.enable" = true;
          "json.format.keepLines" = true;

          "keyboard.dispatch" = "keyCode";

          "latex-workshop.message.update.show" = false;
          "latex-workshop.view.pdf.viewer" = "tab";

          "markdown.preview.fontFamily" =
            "-apple-system, BlinkMacSystemFont, 'DejaVu Sans', 'Segoe WPC', 'Segoe UI', 'HelveticaNeue-Light', 'Ubuntu', 'Droid Sans', sans-serif";

          "mypy-type-checker.importStrategy" = "fromEnvironment";
          "mypy.dmypyExecutable" = "${pkgs.mypy}/bin/dmypy";
          "mypy.runUsingActiveInterpreter" = true;

          "notebook.cellToolbarLocation" = {
            default = "right";
            jupyter-notebook = "left";
          };

          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "${lib.getExe pkgs.nil}";
          "nix.serverSettings" = {
            nil = {
              formatting.command = [ (lib.getExe pkgs.nixfmt-rfc-style) ];
            };
          };

          "npm.fetchOnlinePackageInfo" = false;

          "python.analysis.autoImportCompletions" = true;
          "python.analysis.stubPath" = "./typings/";
          "python.defaultInterpreterPath" = lib.getExe pkgs.python3;
          "python.linting.enabled" = false;
          "python.showStartPage" = false;

          "redhat.telemetry.enabled" = false;

          "scm.alwaysShowProviders" = true;

          "security.workspace.trust.banner" = "never";

          "telemetry.telemetryLevel" = "off";

          "typescript.updateImportsOnFileMove.enabled" = "always";

          "update.mode" = "none";
          "update.showReleaseNotes" = false;

          "vscode-neovim.neovimPath" = lib.getExe pkgs.neovim;

          "vsintellicode.modify.editor.suggestSelection" = "automaticallyOverrodeDefaultValue";

          "window.menuBarVisibility" = "toggle";
          "window.titleBarStyle" = "native";

          "workbench.colorTheme" = "Default Dark Modern";
          "workbench.editorAssociations" = {
            "*.ipynb" = "jupyter-notebook";
          };
          "workbench.enableExperiments" = false;
          "workbench.settings.enableNaturalLanguageSearch" = false;

          "yaml.format.enable" = false;

        };
      };
    };

  };

}
