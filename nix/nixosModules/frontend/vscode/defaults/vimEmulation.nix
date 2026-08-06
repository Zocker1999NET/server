{
  lib,
  pkgs,
  ...
}:
{

  # _class = "homeManager.vscodeProfile";

  extensions = with pkgs.vscode-extensions; [
    # cSpell:disable
    vscodevim.vim
    # cSpell:enable
  ];

  keybindingsByKey = {
    # disable overlapping with vim plugin
    "ctrl+p" = lib.singleton {
      command = "-extension.vim_ctrl+p";
      when = "editorTextFocus && vim.active && vim.use<C-p> && !inDebugRepl || vim.active && vim.use<C-p> && !inDebugRepl && vim.mode == 'CommandlineInProgress' || vim.active && vim.use<C-p> && !inDebugRepl && vim.mode == 'SearchInProgressMode'";
    };
  };

  userSettings = {
    "vim.handleKeys" = {
      "<C-d>" = true; # was default
      "<C-k>" = false; # conflicts with vscode CTRL+k keybindings
      "<C-s>" = false; # conflicts with save
      "<C-z>" = false; # conflicts with undo
      "<C-i>" = false; # conflicts with inline chat
    };
    "vim.neovimPath" = lib.getExe pkgs.neovim;
    "vim.smartRelativeLine" = true;
  };

}
