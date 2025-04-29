{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  # helpers
  inherit (builtins) attrNames elem;
  inherit (lib) types;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.trivial) pipe;
  inherit (lib.options) mkOption;
in
{

  options = {
    groups = mkOption {
      description = ''
        Groups this interface should be added to.

        These are logical groups useable in some firewall rules,
        which have no consequence of themselves in the final config.

        This list might not reflect all groups this interface is member of.
        This is rather the job of {option}`x-banananetwork.routerVM.references.interfaceGroups`,
        which also gets reflected in {option}`ifCfg.effectiveGroups`.
      '';
      type = with types; listOf str;
      default = [ ];
      example = [ "vpn" ];
    };
    effectiveGroups = mkOption {
      description = "all groups this interface was added to";
      readOnly = true;
      type = with types; listOf str;
      default = pipe globalArg.cfg.references.interfaceGroups [
        (filterAttrs (_: elem ifCfg.name))
        attrNames
      ];
    };
  };

}
