# module for generic devices under interactive usage
# (e.g. desktops, laptops, media players, game consoles, etc.)
# - base module, to be imported by interactive* modules
# - not meant to be used directly in nixos configs
{
  config,
  ...
}:
let
  sysAutoUp = config.system.autoUpgrade;
in
{

  _class = "nixos";

  config = {

    # lists reasoning
    assertions = [
      {
        assertion = sysAutoUp.enable -> sysAutoUp.operation != "switch";
        message = "system.autoUpgrade.operation must not be 'switch' for interactive base, because switching while in use can lead to problems";
      }
    ];

    system.autoUpgrade = {
      operation = "boot";
    };

  };

}
