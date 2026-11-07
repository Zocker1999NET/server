# module for appliances under non-permanent interactive usage
# (e.g. media players, game consoles, etc.)
# - suppresses services interfering with user (e.g. system.autoUpgrade)
# - allows or even encourages services to run during non-interactive times, e.g. at night
# - configures and/or asserts settings
{
  config,
  lib,
  ...
}:
let
  inherit (lib.modules) mkForce mkIf;

  sysAutoUp = config.system.autoUpgrade;
in
{

  _class = "nixos";

  imports = [
    ./appliance.nix
    ./interactiveDevice.nix
  ];

  config = {

    # lists reasoning
    assertions = [
      {
        assertion = (sysAutoUp.enable && sysAutoUp.allowReboot) -> sysAutoUp.rebootWindow != null;
        message = "system.autoUpgrade.rebootWindow must be set for interactive appliances, because allowing reboots without a time window is not friendly";
      }
    ];

    # TODO remove tie breaker when no longer needed
    system.autoUpgrade.operation = mkForce "boot";

  };

}
