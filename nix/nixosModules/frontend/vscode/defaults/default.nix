{
  # _class = "homeManager.vscodeProfile";
  imports = [
    ./design.nix
    ./devContainers.nix
    ./direnv.nix
    ./disableTelemetry.nix
    ./files.nix
    ./forge_github.nix
    ./formatAllFiles.nix
    ./keybindings.nix
    ./llm-agent.nix
    ./preferences.nix
    ./spellcheck.nix
    ./vimEmulation.nix
    # cross-import
    ../ide/_builtin.nix
  ];
}
