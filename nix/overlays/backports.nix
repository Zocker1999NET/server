{ lib, ... }@flakeArg:
{ pkgs_unstable, ... }@systemArg:
lib.backport.backportingOverlay pkgs_unstable {
  ncspot = "25.11"; # or https://github.com/NixOS/nixpkgs/pull/438048
  # should always be compatible & improve experience
  retroarch-joypad-autoconfig = "99.99";
}
