{
  pkgs,
  ...
}:
{
  # _class = "homeManager.vscodeProfile";
  extensions = with pkgs.vscode-extensions; [
    mathiasfrohlich.kotlin
  ];
}
