{
  _class = "flake";
  # some checks are supplied via flakeModules
  imports = [
    ./nixosTests
  ];
}
