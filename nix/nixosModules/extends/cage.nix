{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.cage;
  inherit (builtins) concatLists;
  inherit (lib) types;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.cli) toGNUCommandLine;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkBefore mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.strings) escapeShellArgs;
  inherit (lib.trivial) pipe;
in
{

  _class = "nixos";

  options.services.cage = {

    commands = mkOption {
      description = ''
        Shell commands which are run within cage,
        overriding {option}`services.cage.program`.
      '';
      type = with types; nullOr lines;
      default = null;
      example = "firefox --kiosk https://example.com";
    };

    wlr-randr = mkOption {
      description = ''
        Configure display outputs for cage using {command}`wlr-randr`.

        The outer attrset keys are the output names.
        The inner attrset keys are the options for {command}`wlr-randr`,
        for all see {man}`wlr-randr(1)`.

        The resulting command is prepended to {option}`services.cage.commands` using {var}`mkBefore`.
      '';
      type = with types; attrsOf (attrsOf str);
      default = null;
      example.Virtual-1 = {
        mode = "1360x768@60Hz";
        scale = "1.3";
      };
    };

  };

  config.services.cage = {

    program = mkIf (cfg.commands != null) (
      getExe (
        pkgs.writeShellApplication {
          name = "cage-commands";
          bashOptions = [
            "errexit"
            "nounset"
            "pipefail"
            "xtrace"
          ];
          text = cfg.commands;
        }
      )
    );

    commands = pipe cfg.wlr-randr [
      (mapAttrsToList (
        output: opts:
        [
          "--output"
          output
        ]
        ++ (toGNUCommandLine { } opts)
      ))
      concatLists
      escapeShellArgs
      (s: "${getExe pkgs.wlr-randr} ${s} || true")
      mkBefore
      (mkIf (cfg.wlr-randr != null))
    ];

  };

}
