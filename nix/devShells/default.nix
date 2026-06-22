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
              # tooling for services
              bind # e.g. dnssec-keygen
              wireguard-tools
              # MCPs for AI
              mcp-nixos
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
