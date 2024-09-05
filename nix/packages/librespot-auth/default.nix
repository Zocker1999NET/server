{
  stdenv,
  lib,
  fetchFromGitHub,
  # from flake
  craneLib,
}:

# TODO temporary useful due to https://github.com/hrkfdn/ncspot/issues/1500
craneLib.buildPackage rec {
  pname = "librespot-auth";
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "dspearson";
    repo = "librespot-auth";
    rev = "v${version}";
    hash = "sha256-IbbArRSKpnljhZSgL0b3EjVzKWN7bk6t0Bv7TkYr8FI=";
  };

  buildInputs = [ ];

  enableParallelBuilding = true;

  # Ensure Rust compiles for the right target
  env.CARGO_BUILD_TARGET = stdenv.hostPlatform.rust.rustcTarget;

  meta = with lib; {
    description = "A simple program for populating a `credentials.json` for librespot via Spotify's zeroconf authentication.";
    homepage = "https://github.com/dspearson/librespot-auth";
    changelog = "https://github.com/dspearson/librespot-auth/releases/tag/v${version}";
    license = licenses.isc;
    mainProgram = "librespot-auth";
  };
}
