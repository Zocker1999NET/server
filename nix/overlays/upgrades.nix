{ lib, ... }@flakeArg:
{ pkgs, ... }@systemArg:
final: prev: {
  ptouch-print = prev.ptouch-print.overrideAttrs (old: {
    version = "1.6";
    src = pkgs.fetchgit {
      url = "https://git.familie-radermacher.ch/linux/ptouch-print.git";
      rev = "aa5392bc135161252d06c48745c0d53c281d69f3";
      hash = "";
    };
  });
}
