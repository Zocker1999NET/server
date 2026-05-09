{
  ...
}@flakeArg:
{

  _class = "flake";

  perSystem =
    { importWithSystem, ... }@systemArg:
    {
      checks = importWithSystem ./legacy.nix;
    };

}
