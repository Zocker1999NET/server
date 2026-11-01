{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
in
{

  # _class = "homeManager.vscodeProfile";

  extensions = with pkgs.vscode-extensions; [
    jnoortheen.nix-ide
  ];

  userMcp.servers.mcp-nixos = {
    type = "stdio";
    command = getExe pkgs.mcp-nixos;
  };

  userSettings = {
    "[nix]" = {
      "editor.tabSize" = 2;
    };

    "nix.enableLanguageServer" = true;
    # hide errors which appear during normal coding
    # see https://github.com/nix-community/vscode-nix-ide/issues/387
    "nix.hiddenLanguageServerErrors" = [
      "textDocument/definition"
      "textDocument/documentSymbol"
      "textDocument/formatting"
    ];
    "nix.serverPath" = getExe pkgs.nil;
    "nix.serverSettings" = {
      nil = {
        formatting.command = singleton (getExe pkgs.nixfmt);
      };
    };
  };

}
