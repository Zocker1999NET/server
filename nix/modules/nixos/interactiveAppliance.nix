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
  inherit (lib.modules) mkIf;

  sysAutoUp = config.system.autoUpgrade;
in
{

  _class = "nixos";

  imports = [
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
    warnings = [
      # (should be set where other settings like timings are configured)
      (mkIf (
        !sysAutoUp.enable
      ) "system.autoUpgrade.enable recommended for interactive appliances to not forget to upgrade them")
    ];

  };

}
