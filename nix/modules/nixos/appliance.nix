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

  config = {

    # list reasoning
    warnings = [
      # (should be set where other settings like timings are configured)
      (mkIf (
        !sysAutoUp.enable
      ) "system.autoUpgrade.enable recommended for appliances to not forget to upgrade them")
    ];

    # server configs provide useful settings for appliances
    # TODO extract its settings here
    x-banananetwork.serverCommon.enable = true;

  };

}
