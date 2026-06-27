{
  pkgs,
  ...
}:
{

  # _class = "homeManager.vscodeProfile";

  extensions = with pkgs.nix-vscode-extensions.vscode-marketplace-release; [
    # cSpell:disable
    mjmorales.generic-lsp-proxy
    # cSpell:enable
  ];

  # TODO configure

}
