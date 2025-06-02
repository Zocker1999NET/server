{
  # build helpers
  callPackage,
  fetchFromGitHub,
  python3Packages,
  ...
}:
python3Packages.buildPythonApplication rec {
  pname = "taskcheck";
  version = "1.0.0-2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "00sapo";
    repo = "taskcheck";
    rev = "v${version}";
    hash = "sha256-Cufie7mfvrhftJYUEPUc33n5mQwrE2S+BXO7e1OVGfQ=";
  };

  build-system = with python3Packages; [
    setuptools
  ];

  dependencies = with python3Packages; [
    appdirs
    icalendar
    (callPackage ./random-unicode-emoji.nix { })
    requests
    rich
  ];
}
