{ lib, ... }@flakeArg:
{ pkgs_unstable, ... }@systemArg:
lib.backport.backportingOverlay pkgs_unstable {
  # should always be compatible & improve experience
  retroarch-joypad-autoconfig = "99.99";
}
