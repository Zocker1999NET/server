{
  _class = "nixos";
  imports = [
    # files
    ./efi.nix
    ./environment-shellChecks.nix
    ./fileSystems.nix
    ./mdns.nix
    ./nixos.nix
    ./registry.nix
  ];
}
