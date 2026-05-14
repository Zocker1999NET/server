{
  config,
  ...
}:
{
  _class = "flake";
  flake.modules.generic = {

    # useful when not being able to inject from the outside those
    # e.g. with: specialArgs = config.flakeSpecialArgs
    # setting outside is to be preferred for being able to import from those
    # required to be inline for injecting args
    _injectSpecialArgs.config._module.args = config.flakeSpecialArgs;

  };
}
