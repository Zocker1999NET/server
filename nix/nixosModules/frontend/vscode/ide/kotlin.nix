{
  pkgs,
  ...
}:
{

  # _class = "homeManager.vscodeProfile";

  extensions = with pkgs.nix-vscode-extensions.vscode-marketplace-release; [
    # cSpell:disable
    jetbrains.kotlin-server
    # cSpell:enable
  ];

}
