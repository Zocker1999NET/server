{
  self,
  ...
}:
{
  _class = "flake";
  flake.modules.nixosTest = rec {

    # collection of modules I expect to be always enabled
    _default.imports = [
      self.modules.generic._injectSpecialArgs
    ];

  };
}
