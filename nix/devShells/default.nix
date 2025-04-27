{ outputs, ... }@flakeArg:
{ pkgs_unstable, system, ... }@sysArg:
let
  pkgs = pkgs_unstable;
in
{
  default = pkgs.mkShell {
    packages =
      (with pkgs; [
        curl
        mkpasswd
        rsync
        opentofu
        terranix
        xkcdpass
        # tooling for services
        bind # e.g. dnssec-keygen
        wireguard-tools
      ])
      ++ [
        # flake stuff
        outputs.packages.${system}.secrix-wrapper
      ];
    # TODO magic
    shellHook = ''
      export SECRIX_ID=~/".ssh/id_ed25519"
    '';
  };
}
