# ../../flakes.nix expects this to just be a NixOS module
{

  imports = [
    # directories
    ./extends
    ./frontend
    ./improvedDefaults
    # files
    ./allCommon.nix
    ./autoUnfree.nix
    ./debugMinimal.nix
    ./graphics.nix
    ./hwCommon.nix
    ./kernel.nix
    ./options.nix
    ./privacy.nix
    ./secrix.nix
    ./sshSecurity.nix
    ./useable.nix
    ./vmCommon.nix
  ];

}
