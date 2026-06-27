{
  pkgs,
  ...
}:
{

  # _class = "homeManager.vscodeProfile";

  extensions = with pkgs.vscode-extensions; [
    # cSpell:disable
    jbockle.jbockle-format-files
    # cSpell:enable
  ];

}
