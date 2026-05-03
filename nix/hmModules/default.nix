{ lib, ... }@flakeArg:
rec {

  assertions.imports = lib.singleton ./assertions;

  # combination of all my custom modules
  # these should not change anything until you enable their custom options
  default.imports = [
    # standalone (exposed on their own as well)
    assertions
    # non-standalone (only exposed through this)
    ./extends
  ];

}
