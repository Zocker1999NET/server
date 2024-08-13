# ../../flakes.nix expects this to just be a NixOS module
{

  imports = [
    # directories
    ./frontend
    # files
    ./allCommon.nix
    ./autoUnfree.nix
    ./convertable.nix
    ./graphics.nix
    ./hwCommon.nix
    ./privacy.nix
    ./sshSecurity.nix
    ./useable.nix
    ./vmCommon.nix
  ];

}
