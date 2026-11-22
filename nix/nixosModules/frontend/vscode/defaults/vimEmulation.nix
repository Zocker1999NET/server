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

  userSettings = {
    "vim.handleKeys" = {
      "<C-d>" = true; # was default
      "<C-k>" = false; # conflicts with vscode CTRL+k keybindings
      "<C-p>" = false; # conflicts with vscode CTRL+p quick open
      "<C-s>" = false; # conflicts with save
      "<C-z>" = false; # conflicts with undo
      "<C-i>" = false; # conflicts with inline chat
    };
    "vim.neovimPath" = lib.getExe pkgs.neovim;
    "vim.smartRelativeLine" = true;
  };

}
