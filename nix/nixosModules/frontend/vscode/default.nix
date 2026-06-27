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
      default = imports [
        ./p_default.nix
        ./disableTelemetry.nix
        ./design.nix
        ./files.nix
        ./forge_github.nix
        ./formatAllFiles.nix
        ./keybindings.nix
        ./llm-agent.nix
        ./preferences.nix
        ./spellcheck.nix
        ./vimEmulation.nix
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
    };

  };
}
