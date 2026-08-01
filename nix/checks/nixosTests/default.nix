{
  ...
}@flakeArg:
{

  _class = "flake";

  imports = [
    ./diskoInstallMenu.nix
    ./firefox-render.nix
  ];

  perSystem =
    { importWithSystem, ... }@systemArg:
    {
      checks = importWithSystem ./legacy.nix;
    };

}
