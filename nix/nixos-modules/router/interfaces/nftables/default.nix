{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  inherit (lib) mkOutputOption;
  inherit (lib.options) mkOption;
in
{

  imports = [
    # files
    ./chains.nix
    ./lists.nix
  ];

  options.nftables = {
    content = mkOption {
      internal = true;
      description = ''
        Resulting firewall rules for this interface. Chain decides about hook.
      '';
      type = lib.types.lines;
    };
    namePrefix = mkOutputOption {
      internal = true;
      description = "prefix for all nftables names";
      default = ifCfg.name;
    };
  };

}
