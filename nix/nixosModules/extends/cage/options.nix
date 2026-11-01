{
  config,
  lib,
  ...
}:
let
  cfg = config.services.cage;

  inherit (builtins)
    attrNames
    concatStringsSep
    filter
    mapAttrs
    ;
  inherit (lib) types;
  inherit (lib.attrsets) mapAttrsToList mergeAttrsList;
  inherit (lib.lists) optionals;
  inherit (lib.modules) mkMerge;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) flip pipe;

  # most descriptions are from https://github.com/cage-kiosk/cage/blob/0ff64aa3d9409ce29625f8232975dab56bb025ac/cage.1.scd

  # boolean options
  cageOpts = {
    allowVTSwitching = {
      description = "allow VT switching";
      flag = "-s";
    };
    enableDebugLogging = {
      description = "enable debug logging";
      flag = "-D";
    };
    dontDrawClientSideDecorations = {
      description = "don't draw client side decorations when possible";
      flag = "-d";
    };
  };

  # enum options
  multiModes = {
    last = "uses only the last connected monitor";
    extend = "extends the display across all connected monitors";
  };
in
{

  options.services.cage.options = mergeAttrsList [

    # boolean options
    (flip mapAttrs cageOpts (
      _:
      { description, flag }:
      mkOption {
        description = ''
          Whether to ${description} in Cage.

          Corresponds to the `${flag}` flag.
        '';
        type = types.bool;
        default = false;
        example = true;
      }
    ))

    # enum options
    {
      multiMonitorBehavior = mkOption {
        description = ''
          Set the multi-monitor behavior for cage.

          ${pipe multiModes [
            (mapAttrsToList (a: b: "  * **`${a}`**: ${b}"))
            (concatStringsSep "\n")
          ]}
        '';
        type = with types; nullOr (enum (attrNames multiModes));
        default = null;
        example = "last";
      };
    }

  ];

  config.services.cage.extraArguments = mkMerge [

    # boolean options
    (pipe cageOpts [
      (mapAttrsToList (opt: { flag, ... }: if cfg.options.${opt} then flag else null))
      (filter (x: x != null))
    ])

    # enum options
    (optionals (cfg.options.multiMonitorBehavior != null) [
      "-m"
      cfg.options.multiMonitorBehavior
    ])

  ];

}
