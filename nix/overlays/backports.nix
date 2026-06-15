{ libBNet, ... }@flakeArg:
{ pkgs_unstable, ... }@systemArg:
let
  infinite = "999.99";
in
libBNet.backport.backportingOverlay pkgs_unstable {
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
