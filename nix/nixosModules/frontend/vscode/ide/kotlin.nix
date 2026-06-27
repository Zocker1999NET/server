{
  pkgs,
  ...
}:
{

  # _class = "homeManager.vscodeProfile";

  imports = [
    ../requisites/genericLspSetup.nix
  ];

  extensions = with pkgs.vscode-extensions; [
    mathiasfrohlich.kotlin
  ];

}
