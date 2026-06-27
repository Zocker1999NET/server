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
        ./design.nix
        ./forge_github.nix
        ./keybindings.nix
        ./llm-agent.nix
        ./spellcheck.nix
        ./vimEmulation.nix
        # IDEs
        ./ide/ansible.nix
        ./ide/kotlin.nix
        ./ide/latex.nix
        ./ide/nix.nix
        ./ide/python.nix
        ./ide/svelte.nix
      ];
    };

  };
}
