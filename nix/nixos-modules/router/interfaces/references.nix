{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  inherit (lib) types;
  inherit (lib.options) mkOption;
in
{

  options.references = {
    macToIPv4 = mkOption {
      internal = true;
      description = "mapping from known MAC addresses to their defined static addresses";
      type = types.attrsOf types.ipv4AddressPlain;
      default = { };
    };
  };

}
