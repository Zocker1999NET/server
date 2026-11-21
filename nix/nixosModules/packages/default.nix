{
  _class = "nixos";
  imports = [
    # files
    ./dns-dynamic-primary-reflector.nix
    ./nft-update-addresses.nix
  ];
}
