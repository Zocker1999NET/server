{
  lib,
  writeText,
  python3Packages,
  curl,
  mypy,
}:
let
  version = "2026.11.18";
  project_toml = writeText "dns-dynamic-primary-reflector_pyproject" ''
    [build-system]
    requires = ["setuptools >= 61.0"]
    build-backend = "setuptools.build_meta"
    [project]
    name = "dns-dynamic-primary-reflector"
    version = "${version}"
    requires-python = ">= 3.11"
    [project.scripts]
    dns-dynamic-primary-reflector = "dns_dynamic_primary_reflector:main"
  '';
in
python3Packages.buildPythonPackage {
  name = "dns-dynamic-primary-reflector";
  inherit version;
  format = "pyproject";

  build-system = lib.singleton python3Packages.setuptools;

  dependencies = with python3Packages; [
    dnspython
    hcloud
    requests
    types-requests
  ];

  propagatedBuildInputs = [
    curl
  ];

  unpackPhase = ''
    cp ${project_toml} ./pyproject.toml
    mkdir ./src
    cp -rT ${./../../../scratchs/hetzner-dns/dns_dynamic_primary_reflector} ./src/dns_dynamic_primary_reflector
    chmod --recursive u=rwX ./src  # required so further build steps can create wrapper files
    ${lib.getExe mypy} --strict ./src
  '';

  meta = {
    description = "Keeps Hetzner DNS primary nameservers in sync with the dynamic public IPs of the home primary DNS server";
    mainProgram = "dns-dynamic-primary-reflector";
  };
}
