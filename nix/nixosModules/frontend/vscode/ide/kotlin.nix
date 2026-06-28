{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.meta) getExe;
in
{

  # _class = "homeManager.vscodeProfile";

  imports = [
    ../requisites/genericLspSetup.nix
  ];

  genericLspProxy = {
    languageId = "kotlin";
    command = getExe pkgs.kotlin-language-server;
    fileExtensions = [
      ".kt"
      ".kts"
    ];
  };

}
