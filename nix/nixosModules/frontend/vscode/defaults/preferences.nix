# UX preferences, not purely visual
{
  # _class = "homeManager.vscodeProfile";
  userSettings = {

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

    "files.autoSave" = "onFocusChange";
    "files.insertFinalNewline" = true;
    "files.trimTrailingWhitespace" = true;

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

    "notebook.cellToolbarLocation" = {
      default = "right";
      jupyter-notebook = "left";
    };

    "npm.fetchOnlinePackageInfo" = false;

    "security.workspace.trust.banner" = "never";

    "terminal.integrated.stickyScroll.enabled" = false; # annoying because it covers the prompt and the command output

    "update.showReleaseNotes" = false;

    "window.menuBarVisibility" = "toggle";
    "window.titleBarStyle" = "native";

    "workbench.editor.useModal" = "off"; # disables annoying Settings popup instead of the normal editor
    "workbench.enableExperiments" = false;
    "workbench.settings.alwaysShowAdvancedSettings" = true;
    "workbench.settings.enableNaturalLanguageSearch" = false;

    # === workarounds (with link to upstream issue / explanation)

    # https://github.com/microsoft/vscode/issues/308152#issuecomment-4281470710
    "terminal.integrated.enableKittyKeyboardProtocol" = false;

  };
}
