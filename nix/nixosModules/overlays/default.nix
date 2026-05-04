# This file especially especially includes special overlays
# where a full include via the nixpkgs.overlays option is not feasible
# because of a big list of dependencies
# and where in most cases just setting a certain package option should be enough (e.g. systemd).
{
  inputs,
  lib,
  self,
  ...
}@flakeArg:
let
  withOverlay =
    overlay: configFun:
    { pkgs, ... }:
    configFun (
      import inputs.nixpkgs {
        system = pkgs.system;
        overlays = lib.singleton overlay;
      }
    );
in
{
  _class = "flake";
  flake.nixosModules = {

    # TODO until https://github.com/systemd/systemd/issues/29651 is fixed
    systemd-radv-fadeout = withOverlay self.overlays.systemd-radv-fadeout (pkgs: {
      config.systemd.package = pkgs.systemd;
    });

  };
}
