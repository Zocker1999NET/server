{
  hmConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = hmConfig.programs.vscode;

  mktPlc = pkgs.nix-vscode-extensions;
in
{

  # _class = "homeManager.vscodeProfile";

  enableExtensionUpdateCheck = cfg.mutableExtensionsDir;
  enableUpdateCheck = false;
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

    "diffEditor.ignoreTrimWhitespace" = false;
    "diffEditor.renderSideBySide" = false;

    "editor.cursorBlinking" = "solid";
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

    "html.format.enable" = false;

    "json.format.enable" = true;
    "json.format.keepLines" = true;

    "notebook.cellToolbarLocation" = {
      default = "right";
      jupyter-notebook = "left";
    };

    "npm.fetchOnlinePackageInfo" = false;

    # here just in case
    "redhat.telemetry.enabled" = false;

    "scm.alwaysShowProviders" = true;

    "security.workspace.trust.banner" = "never";

    "telemetry.telemetryLevel" = "off";

    "terminal.integrated.enableKittyKeyboardProtocol" = false; # https://github.com/microsoft/vscode/issues/308152#issuecomment-4281470710

    "typescript.updateImportsOnFileMove.enabled" = "always";

    "update.showReleaseNotes" = false;

    "vsintellicode.modify.editor.suggestSelection" = "automaticallyOverrodeDefaultValue";

    "window.menuBarVisibility" = "toggle";
    "window.titleBarStyle" = "native";

    "workbench.enableExperiments" = false;
    "workbench.settings.enableNaturalLanguageSearch" = false;

  };
}
