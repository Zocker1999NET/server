{
  inputs,
  ...
}@flakeArg:
{
  _class = "flake";
  perSystem =
    {
      inputs',
      pkgs,
      self',
      ...
    }@sysArg:
    let
      inherit (pkgs) callPackage;
      craneLib = inputs.crane.mkLib pkgs;
    in
    {
      packages = {

        librespot-auth = callPackage ./librespot-auth { inherit craneLib; };

        nft-update-addresses = callPackage ./nft-update-addresses { };

        pdfpagecount = callPackage ./pdfpagecount { };

        secrix-wrapper = callPackage ./secrix-wrapper {
          secrixExe = self'.apps.secrix.program;
        };

        taskcheck = callPackage ./taskcheck { };

        zfs-tools = callPackage ./zfs-tools { };

        # === packages inherited from flake inputs

        inherit (inputs'.pkgs_streamlined-client.packages) streamlined-client;

      };
    };
}
