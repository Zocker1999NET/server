# programs.vscode.profiles submodule
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) concatLists isAttrs;
  inherit (lib) types;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) flip mergeAttrs pipe;

  # copied from https://github.com/nix-community/home-manager/blob/282e1e029cb6ab4811114fc85110613d72771dea/modules/programs/vscode.nix#L129-L160
  # (excluding options.key)
  jsonFormat = pkgs.formats.json { };

  keybindingModule = types.submodule {
    options = {
      command = mkOption {
        type = types.str;
        example = "editor.action.clipboardCopyAction";
        description = "The VS Code command to execute.";
      };

      when = mkOption {
        type = types.nullOr (types.str);
        default = null;
        example = "textInputFocus";
        description = "Optional context filter.";
      };

      # https://code.visualstudio.com/docs/getstarted/keybindings#_command-arguments
      args = mkOption {
        type = types.nullOr (jsonFormat.type);
        default = null;
        example = {
          direction = "up";
        };
        description = "Optional arguments for a command.";
      };
    };
  };

in
{

  options.keybindingsByKey = mkOption {
    description = ''
      More expressive and ordered way to set {option}`programs.vscode.keybindings`.
      Both options can be used simultaneously if `keybindings` is not a path.

      - key bindings are grouped by their key combination
      - you can shortcut commands without further options (see example)
    '';
    type = with types; attrsOf (listOf (either str keybindingModule));
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

  config.keybindings =
    let
      useAsDefaultAttr = name: value: if isAttrs value then value else { ${name} = value; };
      transformKeyAttr =
        key:
        map (
          flip pipe [
            (useAsDefaultAttr "command")
            (mergeAttrs { inherit key; })
          ]
        );
    in
    pipe config.keybindingsByKey [
      (mapAttrsToList transformKeyAttr)
      concatLists
    ];

}
