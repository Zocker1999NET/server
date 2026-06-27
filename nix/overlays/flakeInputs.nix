# maps overlays from flake inputs
#
# however restricts their "write" access to the packages I expect to use from them, for:
# - increasing security (restricting malicious overlays reach)
# - allowing some host configurations to be built without the need to fetch all inputs used here
#   (giving a future Nix version gains support for this)

{
  inputs,
  lib,
  ...
}@flakeArg:
{ ... }@systemArg:
final: prev:
let

  inherit (builtins) isFunction mapAttrs;
  inherit (lib.trivial) flip pipe;
  loadOverlay = flip pipe [
    (x: if isFunction x then x else x.overlays.default)
    (o: o final prev)
  ];

  # specify which overlays from flake inputs to load
  #   usage: <loaded-name> = inputs.<name> or inputs.<name>.overlays.<name>
  #   (name <loaded-name> only relevant for below)
  O = mapAttrs (_: loadOverlay) {
    inherit (inputs) nix-vscode-extensions;
  };

in

# specify which packages to expose from the overlays loaded above
#   usage: inherit (O.<loaded-name>) <pkg> …;
{

  inherit (O.nix-vscode-extensions) nix-vscode-extensions;

}
