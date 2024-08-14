{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.x-banananetwork.improvedDefaults;
in
{


  config = lib.mkIf cfg.enable (
    let
      powertop = config.powerManagement.powertop;
      tlp = config.services.tlp;
    in
    {

      assertions = [
        {
          assertion = tlp.enable -> !powertop.enable;
          message = "tlp makes powertop service useless, see https://linrunner.de/tlp/faq/powertop.html#does-powertop-conflict-with-tlp";
        }
      ];

    }
  );


}
