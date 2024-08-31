{
  config,
  lib,
  options,
  ...
}:
let
  cfg = config.programs.vscode;
in
{

  options.programs.vscode = {
    keybindingsNext = lib.mkOption {
      description = ''
        More expressive and ordered way to set {option}`programs.vscode.keybindings`.
        Both options can be used simultaneously.

        - key bindings are grouped by their key combination
        - you can shortcut commands without further options (see example)
      '';
      type =
        let
          bindsType = options.programs.vscode.keybindings.type;
          bindModule = bindsType.nestedTypes.elemType;
          bindOpts = bindModule.getSubOptions;
          inhOpts =
            prefix:
            builtins.removeAttrs (bindOpts prefix) [
              "_module"
              "key"
            ];
          inhMod = lib.types.submodule { options = inhOpts [ ]; };
          commType = (bindOpts [ ]).command.type;
          bindsNextType = lib.types.either inhMod commType;
          bindsListNext = lib.types.listOf bindsNextType;
        in
        lib.types.attrsOf bindsListNext;
      default = { };
      example = {
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
    };
  };

  config.programs.vscode = {
    keybindings =
      let
        expandEntry = opts: if builtins.isAttrs opts then opts else { command = opts; };
        transEntry = key: opts: (expandEntry opts) // { inherit key; };
        transKey = key: opts: map (transEntry key) opts;
        transAttr = attr: lib.flatten (lib.mapAttrsToList transKey attr);
      in
      transAttr config.programs.vscode.keybindingsNext;
  };

}
