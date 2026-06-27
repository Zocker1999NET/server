{
  lib,
  pkgs,
  ...
}:
{

  # _class = "homeManager.vscodeProfile";

  extensions = with pkgs.vscode-extensions; [
    jnoortheen.nix-ide
  ];

  userSettings = {
    "[nix]" = {
      "editor.tabSize" = 2;
    };

    "nix.enableLanguageServer" = true;
    "nix.serverPath" = "${lib.getExe pkgs.nil}";
    "nix.serverSettings" = {
      nil = {
        formatting.command = [ (lib.getExe pkgs.nixfmt) ];
      };
    };
  };

}
