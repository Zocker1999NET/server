{ lib, ... }@flakeArg:
{ pkgs, ... }@systemArg:
final: prev: {
  pferd = prev.pferd.overrideAttrs (old: rec {
    version = "3.8.1";
    src = pkgs.fetchFromGitHub {
      owner = "Garmelon";
      repo = "PFERD";
      tag = "v${version}";
      sha256 = "sha256-IRQQkQTkP0B3S8j2MFP5W18wt6QsZ5MppAwvOUfE1Yg=";
    };
  });
  ptouch-print = prev.ptouch-print.overrideAttrs (old: {
    version = "1.6";
    src = pkgs.fetchgit {
      url = "https://git.familie-radermacher.ch/linux/ptouch-print.git";
      rev = "aa5392bc135161252d06c48745c0d53c281d69f3";
      hash = "";
    };
  });
}
