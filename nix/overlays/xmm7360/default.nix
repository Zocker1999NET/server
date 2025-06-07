# implement pre-release support for XMM7360 cards
{ lib, ... }@flakeArg:
{ pkgs, ... }@systemArg:
final: prev: {
  # requires overriding modemmanager
  modemmanager = prev.modemmanager.overrideAttrs (old: rec {
    # i.e. upgrading modemmanager
    version = "1.24.0";
    src = pkgs.fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "mobile-broadband";
      repo = "ModemManager";
      rev = version;
      hash = "sha256-3jI75aR2esmv5dkE4TrdCHIcCvtdOBKnBC5XLEKoVFs=";
    };
    patches = [
      # extending this patch from nixpkgs
      ./no-dummy-dirs-in-sysconfdir.patch
      # (removing other patches as already merged upstream)
      # "intel: implement support for RPC-powered xmm7360"
      (pkgs.fetchpatch {
        # (note: merged since 1.25.1-dev)
        url = "https://gitlab.freedesktop.org/mobile-broadband/ModemManager/-/commit/c99c300ad5fa350d0d2269ffde868063d5fb92ce.patch";
        hash = "sha256-Jk6896gIq/+EDLvFMzTIoSOS+6BtJrnGU9aYNoqhV3k=";
      })
    ];
  });
  # requires backporting these dependencies
  libmbim = prev.libmbim.overrideAttrs (old: rec {
    version = "1.32.0";
    src = pkgs.fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "mobile-broadband";
      repo = "libmbim";
      rev = version;
      hash = "sha256-+4INXuH2kbKs9C6t4bOJye7yyfYH/BLukmgDVvXo+u0=";
    };
  });
}
