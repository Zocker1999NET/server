{
  self,
  ...
}:
let
  inherit (builtins) concatLists;

  mods = self.modules;
in
{

  _class = "flake";

  imports = [
    ./_fromNixos.nix
  ];

  flake.modules.nixosTest = rec {

    # collection of modules I expect to be always enabled
    _default.imports = concatLists [
      (with mods.generic; [
        _injectSpecialArgs
      ])
      # from here via rec (more performant)
      [
        _common
        bootloaderDisableAll
        keepTestAssumptions
        networkingDisableMagic
        networkingPreventLeaks
      ]
    ];

    # private modules

    _common = ./_common.nix;

    # public modules

    bootloaderDisableAll = ./bootloaderDisableAll.nix;
    integrationTest = ./integrationTest.nix;
    keepTestAssumptions = ./keepTestAssumptions.nix;
    networkingDisableMagic = ./networkingDisableMagic.nix;
    networkingPreventLeaks = ./networkingPreventLeaks.nix;

  };

}
