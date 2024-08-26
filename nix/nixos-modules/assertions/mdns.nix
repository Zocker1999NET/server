{ config, lib, ... }:
let
  cfgAvahi = config.services.avahi;
  avahiMDNS = cfgAvahi.enable && (cfgAvahi.nssmdns4 || cfgAvahi.nssmdns6);
  cfgResolved = config.services.resolved;
  # TODO check settings when cfgResolved.settings exist
  resolvedMDNS = cfgResolved.enable;
in
{
  config = {

    assertions = [
      {
        assertion = !(avahiMDNS && cfgResolved.enable);
        message = ''
          systemd-resolved is enabled while Avahi mDNS is enabled, disable one of both!
        '';
      }
    ];

  };
}
