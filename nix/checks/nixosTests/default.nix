{
  ...
}@flakeArg:
{

  _class = "flake";

  imports = [
    ./diskoInstallMenu.nix
    # TODO test is broken, re-enable or replace with https://github.com/NixOS/nixpkgs/pull/548283 later
    #./firefox-render.nix
  ];

  perSystem =
    { importWithSystem, ... }@systemArg:
    {
      checks = importWithSystem ./legacy.nix;
    };

}
