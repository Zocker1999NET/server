{
  lib,
  writeText,
  python3Packages,
  mypy,
}:
let
  name = "zfs-tools";
  version = "2025.01.11";
  project_toml = writeText "${name}_pyproject" ''
    [build-system]
    requires = ["setuptools >= 61.0"]
    build-backend = "setuptools.build_meta"
    [project]
    name = "${name}"
    version = "${version}"
    requires-python = ">= 3.11"
    [project.scripts]
    zfs-snap-report = "snap_report:main"
  '';
in
python3Packages.buildPythonPackage {
  inherit name version;
  format = "pyproject";

  build-system = lib.singleton python3Packages.setuptools;

  dependencies = with python3Packages; [
    setuptools
  ];

  unpackPhase = ''
    cp ${project_toml} ./pyproject.toml
    cp -r ${./src} ./src
    chmod --recursive u=rwX ./src  # required so further build steps can create wrapper files
    ${lib.getExe mypy} --strict ./src
  '';

  meta = {
    description = "Provides some rather specialized tools to handle ZFS datasets";
  };
}
