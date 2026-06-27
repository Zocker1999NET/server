{
  lib,
  ...
}:
let
  inherit (lib.lists) toList;
  imports = i: _: { imports = toList i; };
in
{
  _class = "homeManager";
  # VSCode cause faster updates compared to VSCodium
  programs.vscode = {

    enable = true;
    mutableExtensionsDir = false;

    profiles = {
      default = imports [
        ./p_default.nix
        ./keybindings.nix
        ./vimEmulation.nix
      ];
    };

  };
}
