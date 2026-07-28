{ inputs, libBNet, ... }@flakeArg:
{ ... }@systemArg:
let
  infinite = "999.99";
in
libBNet.backport.backportingConfigOverlay inputs.nixpkgs_unstable {
  # because of https://github.com/NixOS/nixpkgs/issues/546491, increases DB version, so cannot remove backport until 26.11 is released
  trilium-desktop = "26.11";
  # backport all VSCode stuff as dev tools to prevent issues with online services
  vscode = infinite;
  vscode-fhs = infinite;
  vscodium = infinite;
  vscodium-fhs = infinite;
  vscode-extensions = infinite;
  # always required to be backported, hopefully always compatible
  yt-dlp = infinite;
  # should always be compatible & improve experience
  retroarch-joypad-autoconfig = infinite;
}
