{
  lib,
  writeText,
  python3Packages,
  iproute2,
  mypy,
}:
let
  version = "2024.09.04";
  project_toml = writeText "dns-update-addresses_pyproject" ''
    [build-system]
    requires = ["setuptools >= 61.0"]
    build-backend = "setuptools.build_meta"
    [project]
    name = "dns-update-addresses"
    version = ${lib.escapeShellArg version}
    requires-python = ">= 3.11"
    [project.scripts]
    dns-update-addresses = "dns_update_addresses:main"
  '';
in
python3Packages.buildPythonPackage {
  name = "dns-update-addresses";
  inherit version;
  format = "pyproject";

  build-system = lib.singleton python3Packages.setuptools;

  dependencies = with python3Packages; [
    attrs
    setuptools
    systemd-python
  ];

  propagatedBuildInputs = [
    iproute2
    #
  ];

  unpackPhase = ''
    mkdir -p ./src/dns_update_addresses
    cp ${project_toml} ./pyproject.toml
    cp ${./dns-update-addresses.py} ./src/dns_update_addresses/__init__.py
    ${lib.getExe mypy} --strict ./src
  '';

  meta = {
    description = "Auto-updates DNS server to reflect dynamic IPs / nets used on dynamic setups, including SLAAC addresses of clients";
    # TODO longDescription
    mainProgram = "dns-update-addresses";
  };
}
