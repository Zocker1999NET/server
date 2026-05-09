{
  inputs,
  lib,
  outputs,
  ...
}@flakeArg:
{ pkgs, system, ... }@sysArg:
let
  inherit (pkgs) callPackage;
  craneLib = inputs.crane.mkLib pkgs;
in
{

  librespot-auth = callPackage ./librespot-auth { inherit craneLib; };

  nft-update-addresses = callPackage ./nft-update-addresses { };

  pdfpagecount = callPackage ./pdfpagecount { };

  secrix-wrapper = callPackage ./secrix-wrapper {
    secrixExe = outputs.apps.${system}.secrix.program;
  };

  taskcheck = callPackage ./taskcheck { };

  zfs-tools = callPackage ./zfs-tools { };

  # === packages inherited from flake inputs

  inherit (inputs.pkgs_streamlined-client.packages."${system}") streamlined-client;

}
