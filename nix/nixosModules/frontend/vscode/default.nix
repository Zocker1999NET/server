{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.vscode;

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

      # TODO remove IDE specific modules (kept to avoid breaking change)
      default = imports [
        ./defaults
        # IDEs
        ./ide/ansible.nix
        ./ide/kotlin.nix
        ./ide/latex.nix
        ./ide/nix.nix
        ./ide/python.nix
        ./ide/svelte.nix
        # only configurable in default profile
        {
          enableExtensionUpdateCheck = cfg.mutableExtensionsDir;
          enableUpdateCheck = false;
        }
      ];

      ansible = imports [
        ./defaults
        ./ide/ansible.nix
      ];

      kotlin = imports [
        ./defaults
        ./ide/kotlin.nix
      ];

      latex = imports [
        ./defaults
        ./ide/latex.nix
      ];

      nix = imports [
        ./defaults
        ./ide/nix.nix
      ];

      python = imports [
        ./defaults
        ./ide/python.nix
      ];

      svelte = imports [
        ./defaults
        ./ide/svelte.nix
      ];

      # esp. for my repos
      sysadmin = imports [
        ./defaults
        ./ide/ansible.nix
        ./ide/python.nix
        ./ide/nix.nix
      ];

    };

  };
}
