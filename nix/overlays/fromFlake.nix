{ ... }@flakeArg:
{ self', ... }@systemArg:
final: prev: {
  inherit (self'.packages)
    # list all universally compatible packages from ./../packages
    librespot-auth
    nft-update-addresses
    pdfpagecount
    streamlined-client
    zfs-tools
    ;
}
