{
  ...
}@flakeArg:
{

  _class = "flake";

  imports = [
    ./diskoInstallMenu.nix
  ];

  perSystem =
    { importWithSystem, ... }@systemArg:
    {
      checks = importWithSystem ./legacy.nix;
    };

}
