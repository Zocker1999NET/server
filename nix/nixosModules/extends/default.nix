{
  _class = "nixos";
  imports = [
    # files
    ./bind-dynamic.nix
    ./cage.nix
    ./cpu.nix
    ./firefox.nix
    ./hunspell.nix
    ./kernel.nix
    ./kodi.nix
    ./nftables-marks.nix
    ./nftables-trace.nix
    ./openssh.nix
    ./podman.nix
    ./printing.nix
    ./samba.nix
    ./tailscale.nix
  ];
}
