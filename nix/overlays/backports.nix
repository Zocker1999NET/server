{ lib, ... }@flakeArg:
{ pkgs_unstable, ... }@systemArg:
final: prev:
let
  list = [
    # TODO until 24.11
    "nixfmt-rfc-style"
    "wcurl"
  ];
  backport =
    pkgAttrName:
    let
      alreadyStable = builtins.hasAttr pkgAttrName prev;
      stableSource = lib.warn "consider removing ${pkgAttrName} from backports list as it is now available on stable" prev;
      source = if alreadyStable then stableSource else pkgs_unstable;
      pkg = builtins.getAttr pkgAttrName source;
    in
    pkg;
in
lib.genAttrs list backport
