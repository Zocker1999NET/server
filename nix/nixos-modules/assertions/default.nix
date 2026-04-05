{
  _class = "nixos";
  imports = [
    # files
    ./efi.nix
    ./fileSystems.nix
    ./mdns.nix
    ./nixos.nix
    ./registry.nix
  ];
}
