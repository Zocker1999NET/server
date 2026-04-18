{ lib, ... }@flakeArg:
{ pkgs_unstable, ... }@systemArg:
let
  infinite = "999.99";
in
lib.backport.backportingOverlay pkgs_unstable {
  ncspot = "25.11"; # or https://github.com/NixOS/nixpkgs/pull/438048
  # always required to be backported, hopefully always compatible
  yt-dlp = infinite;
  # should always be compatible & improve experience
  retroarch-joypad-autoconfig = infinite;
}
