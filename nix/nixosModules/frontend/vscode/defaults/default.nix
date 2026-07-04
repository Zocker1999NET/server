{
  # _class = "homeManager.vscodeProfile";
  imports = [
    # directories
    ./llm-agent
    # files
    ./design.nix
    ./devContainers.nix
    ./direnv.nix
    ./disableTelemetry.nix
    ./files.nix
    ./forge_github.nix
    ./formatAllFiles.nix
    ./keybindings.nix
    ./preferences.nix
    ./spellcheck.nix
    ./vimEmulation.nix
    # cross-import
    ../ide/_builtin.nix
  ];
}
