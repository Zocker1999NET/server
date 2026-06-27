{
  pkgs,
  ...
}:
{

  # _class = "homeManager.vscodeProfile";

  extensions = with pkgs.vscode-extensions; [
    # cSpell:disable
    mkhl.direnv
    # cSpell:enable
  ];

  # TODO configure

}
