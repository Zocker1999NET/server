{
  lib,
  ...
}:
let
  inherit (lib.lists) concatLists;
in
{
  _class = "flake";
  perSystem =
    {
      pkgs_unstable,
      self',
      ...
    }:
    let
      pkgs = pkgs_unstable;
    in
    {
      devShells = {

        default = pkgs.mkShell {
          packages = concatLists [
            (with pkgs; [
              curl
              mkpasswd
              pwgen
              rsync
              xkcdpass
              # Ansible tools
              (python3.withPackages (
                ps: with ps; [
                  ansible-core
                  # community.proxmox
                  proxmoxer
                  requests
                  # IDE related
                  jedi-language-server # required for Pyright
                ]
              ))
              ansible-lint
              # tooling for services
              bind # e.g. dnssec-keygen
              wireguard-tools
            ])
            # flake stuff
            (with self'.packages; [
              secrix-wrapper
            ])
          ];
          # TODO magic
          shellHook = ''
            export SECRIX_ID=~/".ssh/id_ed25519"
          '';
        };

      };
    };
}
