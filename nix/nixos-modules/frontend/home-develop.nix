# parts my frontend home-manager module only applicable to machines used for developing stuff (currently all)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs) runCommand;
  # TODO upstream
  # copies file into its own derivation
  copyFile =
    name: path:
    runCommand name { } ''
      cp -v ${path} "$out"
    '';
in
{

  _class = "homeManager";

  home.packages = with pkgs; [
    # cSpell:disable
    # editors
    neovim
    # general tools
    gnumake
    just
    # nix dev
    nix-output-monitor
    # cSpell:enable
  ];

  programs = {

    direnv = {
      enable = true;
      config = {
        global = {
          hide_env_diff = false;
          strict_env = true;
        };
      };
      enableBashIntegration = false; # explicitly disable for bash so bash can be a fallback for that
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

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
        # disable overlapping with vim plugin
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
          # cSpell:disable
          # general
          jbockle.jbockle-format-files
          mkhl.direnv
          vscodevim.vim
          # AI assistant
          # github.copilot is the deprecated predecessor
          github.copilot-chat
          saoudrizwan.claude-dev # Cline
          # forge integrations
          github.vscode-github-actions
          github.vscode-pull-request-github
          # Spell checker
          streetsidesoftware.code-spell-checker
          streetsidesoftware.code-spell-checker-german
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
          # IDE: Svelte
          svelte.svelte-vscode
          # cSpell:enable
        ];
        userSettings = {

          "[nix]" = {
            "editor.tabSize" = 2;
          };

          "[python]" = {
            "editor.defaultFormatter" = "ms-python.black-formatter";
          };

          "ansible.ansibleLint.path" = "${lib.getExe pkgs.ansible-lint}";

          "black-formatter.path" = "${pkgs.black}/bin/black";

          "chat.disableAIFeatures" = false;
          "chat.tools.urls.autoApprove" = {
            # sorted alphabetically by reversed domain
            "https://github.com/microsoft/vscode/wiki/*" = true;
            "https://docs.github.com" = true;
            "https://code.visualstudio.com" = true;
            "https://nixos.org/manual" = true;
            "https://wiki.nixos.org" = true;
          };

          "cSpell.allowCompoundWords" = false; # enforce camelCasing or snake_casing
          "cSpell.customDictionaries" =
            let
              createDict = name: path: {
                inherit name;
                path = copyFile "cSpell-dict-${name}" path;
                scope = "user";
                addWords = false;
              };
            in
            {
              bnet = createDict "bnet" ./cspell-dicts/bnet.txt;
              nix = createDict "nix" ./cspell-dicts/nix.txt;
              python = createDict "python" ./cspell-dicts/python.txt;
              terms = createDict "terms" ./cspell-dicts/terms.txt;
              # editable dict
              inbox = {
                name = "inbox";
                path = "~/projects/server/nix/nixos-modules/frontend/cspell-dicts/inbox.txt";
                scope = "user";
                addWords = true;
              };
            };
          "cSpell.language" = "en,de";
          "cSpell.languageSettings" = [
            {
              "caseSensitive" = false; # because of package names
              "languageId" = [ "nix" ];
            }
          ];
          "cSpell.spellCheckDelayMs" = 5000; # increase delay to reduce CPU usage, especially for large files

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
          "files.insertFinalNewline" = true;
          "files.trimTrailingWhitespace" = true;
          "files.watcherExclude" = {
            "**/venv" = true;
          };

          "git.autofetch" = true;
          "git.blame.editorDecoration.enabled" = false; # annoying because displayed while editing
          "git.blame.statusBarItem.enabled" = true; # useful, displayed in the bottom right corner
          "git.blame.statusBarItem.template" = "\${subject} (\${authorDateAgo} by \${authorName})";
          "git.confirmSync" = false;
          "git.countBadge" = "all"; # good hint, "tracked" only for specific repos recommended
          "git.defaultCloneDirectory" = "~/projects";
          "git.enableSmartCommit" = true;
          "git.untrackedChanges" = "separate";
          "git.smartCommitChanges" = "tracked";
          "git.requireGitUserConfig" = true; # guessing will always be wrong
          "git.terminalGitEditor" = false; # terminal vim is more natural for that
          "git.verboseCommit" = true;

          "github.gitAuthentication" = false; # prefer native SSH for that
          "github.gitProtocol" = "ssh";

          # define langs for which GitHub Issues should not trigger
          # (i.e. languages where `#` is used frequently)
          "githubIssues.ignoreCompletionTrigger" = [
            # default
            "coffeescript"
            "crystal"
            "diff"
            "dockerfile"
            "dockercompose"
            "ignore"
            "ini"
            "julia"
            "makefile"
            "perl"
            "powershell"
            "python"
            "r"
            "ruby"
            "shellscript"
            "yaml"
            # non-default
            "nix"
          ];

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
          "mypy.mypyExecutable" = "${pkgs.mypy}/bin/mypy";

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

          "terminal.integrated.enableKittyKeyboardProtocol" = false; # https://github.com/microsoft/vscode/issues/308152#issuecomment-4281470710

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
