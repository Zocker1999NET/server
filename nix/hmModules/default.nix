{ lib, self, ... }@flakeArg:
{

  assertions.imports = lib.singleton ./assertions;

  # combination of all my custom modules
  # these should not change anything until you enable their custom options
  default.imports = [
    # flake
    self.assertions
    # directories
    ./extends
  ];

}
