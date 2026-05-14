{
  _class = "flake";
  # some checks are supplied via flakeModules
  imports = [
    # folders
    ./nixosTests
    # files
    ./nixosDocTests.nix
  ];
}
