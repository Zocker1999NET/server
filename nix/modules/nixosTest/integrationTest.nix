{
  config,
  lib,
  libBNet,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.modules) mkDefault mkForce;
  inherit (lib.options) mkOption;
  myTypes = libBNet.types;

  # consts
  exportedName = "tested";

  # values
  tested = config.integrationTested;
  cfg = tested.config;
  sysArgs = tested._banananetwork_systemArgs; # exposed by nix/nixos/default.nix
in
{
  _class = "nixosTest";

  options = {
    integrationTested = mkOption {
      description = "The nixosConfiguration which should be integration-tested.";
      type = myTypes.configuration;
    };
    testScriptExt = mkOption {
      description = ''
        Allows extending {option}`testScript` while keeping integration-tested specifics.

        You may access the {option}`integrationTested` machine as `${exportedName}`.
      '';
      type = types.lines;
      default = ''
        # start machine & verify it boots up correctly
        tested.wait_for_unit("default.target")
      '';
    };
  };

  config = {
    name = mkDefault "${cfg.networking.fqdn}_integration-test";

    # setup selected config
    node.specialArgs = mkForce sysArgs.specialArgs or { };
    nodes.${exportedName}.imports = sysArgs.modules;

    testScript = config.testScriptExt;
  };

}
