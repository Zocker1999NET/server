{
  pkgs,
  ...
}:
{

  # _class = "homeManager.vscodeProfile";

  extensions = with pkgs.vscode-extensions; [
    james-yu.latex-workshop
  ];

  userSettings = {
    "latex-workshop.view.pdf.viewer" = "tab";
  };

}
