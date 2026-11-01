{
  _class = "nixos";
  imports = [
    ./audio.nix
    ./commands.nix
    ./options.nix
    ./webbrowser.nix
    ./wlr-randr.nix
  ];
}
