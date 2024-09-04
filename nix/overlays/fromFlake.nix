{ outputs, ... }@flakeArg:
{ ... }@systemArg:
final: prev: {
  inherit (outputs.packages.${prev.system})
    # list all universally compatible packages from ./../packages
    nft-update-addresses
    ;
}
