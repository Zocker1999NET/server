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
      # from here
      _common
      bootloaderDisableAll
      keepTestAssumptions
      networkingDisableMagic
      networkingPreventLeaks
    ];

    # private modules

    _common = ./_common.nix;

    # public modules

    bootloaderDisableAll = ./bootloaderDisableAll.nix;
    keepTestAssumptions = ./keepTestAssumptions.nix;
    networkingDisableMagic = ./networkingDisableMagic.nix;
    networkingPreventLeaks = ./networkingPreventLeaks.nix;

  };
}
