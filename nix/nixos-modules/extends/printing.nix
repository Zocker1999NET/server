{ config, lib, ... }:
let
  cfg = config.services.printing;
in
{

  options.services.printing = {
    enableAutoDiscovery = lib.mkEnableOption ''
      CUPS automatic discovery of printers.

      This will enable & configure Avahi accordingly,
      including opening ports in the firewall'';
  };

  config = lib.mkIf cfg.enable {
    # TODO make also possible with systemd-resolved
    services.avahi = lib.mkIf cfg.enableAutoDiscovery {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
      openFirewall = true;
    };
  };

}
