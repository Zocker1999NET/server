{
  libBNet,
  pkgs,
  ...
}:
let
  inherit (builtins) concatStringsSep;
  inherit (libBNet.strings) escapeCSSFontFamily;

  listOfCSSFontFamilies = families: concatStringsSep ", " (map escapeCSSFontFamily families);
in
{

  # _class = "homeManager.vscodeProfile";

  extensions = with pkgs.vscode-extensions; [
    vscode-icons-team.vscode-icons
  ];

  userSettings = {

    "editor.fontFamily" = listOfCSSFontFamilies [
      "FiraCode Nerd Font"
      "Fira Code"
      "Droid Sans Mono"
      "monospace"
      "Droid Sans Fallback"
    ];
    "editor.fontLigatures" = true;

    "markdown.preview.fontFamily" = listOfCSSFontFamilies [
      "-apple-system"
      "BlinkMacSystemFont"
      "DejaVu Sans"
      "Segoe WPC"
      "Segoe UI"
      "HelveticaNeue-Light"
      "Ubuntu"
      "Droid Sans"
      "sans-serif"
    ];

    "vsicons.dontShowConfigManuallyChangedMessage" = true;
    "vsicons.projectDetection.autoReload" = true;

    "workbench.colorTheme" = "Dark Modern";
    "workbench.iconTheme" = "vscode-icons";

  };

}
