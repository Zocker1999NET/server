{

  # _class = "homeManager.vscodeProfile";

  keybindingsByKey = {

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

  };

  userSettings = {
    # make bindings independent of keyboard layout
    "keyboard.dispatch" = "keyCode";
  };

}
