{
  # build helpers
  callPackage,
  fetchFromGitHub,
  python3Packages,
  ...
}:
python3Packages.buildPythonApplication rec {
  pname = "taskcheck";
  version = "1.0.0-3";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "00sapo";
    repo = "taskcheck";
    rev = "v${version}";
    hash = "sha256-eTC5PHqIniRSi9pPlS9o7nYtZA1jcs9oKQ3xR+P4Wmw=";
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
