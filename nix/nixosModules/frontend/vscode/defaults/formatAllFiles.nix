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

  userSettings = {
    "formatFiles.inheritWorkspaceExcludedFiles" = true;
    "formatFiles.runOrganizeImports" = true;
    "formatFiles.useGitIgnore" = true;
  };

}
