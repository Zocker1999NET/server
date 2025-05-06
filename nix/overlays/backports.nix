{ lib, ... }@flakeArg:
{ pkgs_unstable, ... }@systemArg:
final: prev:
let
  inherit (builtins) getAttr hasAttr mapAttrs;
  inherit (lib.debug) warn;
  backport =
    name: until:
    let
      alreadyStable = hasAttr name prev && lib.versionAtLeast prev.lib.version until;
      stableSource = warn "consider removing ${name} from backports list as it is now available since ${until}" prev;
      source = if alreadyStable then stableSource else pkgs_unstable;
      pkg = getAttr name source;
    in
    pkg;
in
mapAttrs backport {
  immich = "24.11";
  nixfmt-rfc-style = "24.11";
  taskwarrior3 = "25.05"; # large speed up
  wcurl = "24.11";
  # should always be compatible & improve experience
  retroarch-joypad-autoconfig = "99.99";
}
