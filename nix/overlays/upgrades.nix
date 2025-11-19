{ lib, ... }@flakeArg:
{ pkgs, ... }@systemArg:
final: prev: {
  # to fix ansible-lint, see:
  # - https://github.com/NixOS/nixpkgs/issues/460422
  # - https://github.com/NixOS/nixpkgs/pull/460755
  ansible-compat = prev.ansible-compat.overrideAttrs (old: rec {
    version = "25.8.1";
    src = pkgs.fetchFromGitHub {
      owner = "ansible";
      repo = "ansible-compat";
      tag = "v${version}";
      hash = "sha256-hwfD7B0r8wRo/BUUA00TTQXCkrY8TAUM5BiP4Q4Atd0=";
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
