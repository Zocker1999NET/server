{ lib, self, ... }@flakeArg:
let
  selfMods = self.homeModules;
in
{

  _class = "flake";

  flake.homeModules = {

    assertions = ./assertions;

    # combination of all my custom modules
    # these should not change anything until you enable their custom options
    default.imports = [
      # standalone (exposed on their own as well)
      selfMods.assertions
      # non-standalone (only exposed through this)
      ./extends
    ];

  };

}
