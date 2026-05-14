{
  flakeArg,
  ...
}:
{
  config = {

    defaults = ./nodeCommon.nix;

    node = {
      # allow individual nixpkgs (and so overlays) per node
      # induces extra evaluation time as nixpkgs needs to be evaluated per node
      # TODO rebuild test infrastructure to not rely on this
      pkgsReadOnly = false;
      specialArgs = flakeArg.config.flakeSpecialArgs;
    };

  };
}
