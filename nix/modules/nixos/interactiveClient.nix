# module for clients under permanent interactive usage
# (e.g. desktops, laptops, etc.)
# - suppresses services interfering with user (e.g. system.autoUpgrade)
# - suppresses without exceptions, assuming user could be present at all times
# - configures and/or asserts settings
{
  config,
  ...
}:
let
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
        assertion = sysAutoUp.enable -> !sysAutoUp.allowReboot;
        message = "system.autoUpgrade.allowReboot must not be true for interactive clients, because sudden rebooting while in use is not friendly";
      }
    ];

    system.autoUpgrade = {
      allowReboot = false;
    };

  };

}
