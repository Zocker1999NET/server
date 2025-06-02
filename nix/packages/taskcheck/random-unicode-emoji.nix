{
  fetchFromGitHub,
  python3Packages,
  ...
}:
python3Packages.buildPythonPackage rec {
  pname = "random-unicode-emoji";
  version = "2.9";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "NicPWNs";
    repo = "${pname}-py";
    rev = version;
    hash = "sha256-8BfwcZSzQpq1jJuvavIrW84rDvLfKdXr6TLXP8echM4=";
  };

  build-system = with python3Packages; [
    setuptools
  ];
}
