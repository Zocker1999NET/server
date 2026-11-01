{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.cage;

  inherit (lib) types;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
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

  };

}
