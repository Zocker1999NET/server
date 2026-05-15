# "nixos" modules passed as "nixosTest" modules
{
  lib,
  self,
  ...
}:
let
  inherit (builtins) mapAttrs;
  inherit (lib.attrsets) setAttrByPath;
  inherit (lib.modules) mkMerge;

  passAs = attrPath: mapAttrs (_: setAttrByPath attrPath);

  mods = self.modules.nixos;
in
{
  _class = "flake";
  flake.modules.nixosTest = mkMerge [

    (passAs [ "defaults" ] {
      inherit (mods) flakeSuppressRevision;
    })

  ];
}
