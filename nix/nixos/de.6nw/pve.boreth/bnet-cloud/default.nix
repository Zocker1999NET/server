{ lib, outputs, ... }@flakeArg:
let
  inherit (lib.lists) singleton;
in
{
  modules = [

    # config
    (
      { config, pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          #
        ];
        networking = {
          hostName = "bnet-cloud";
          domain = "boreth.pve.6nw.de";
        };
        services.nextcloud = {
          enable = true;
          appstoreEnable = true;
          autoUpdateApps.enable = true;
          config = {
            adminpassFile = config; # TODO
            adminuser = config.x-banananetwork.userName;
            dbtype = "mysql";
          };
          confiugreImaginary = true;
          configureRedis = true;
          database.createLocally = true;
          enableImagemagick = true;
          hostName = "test-cloud.banananet.work";
          #https = true; # TODO
          nginx.hstsMaxAge = 0; # avoid effective HSTS header from .https=true
          # config.php
          settings = {
            default_phone_region = "DE";
            lost_password_link = "disabled";
            "profile.enabled" = false;
            token_auth_enforced = true;
            # TODO mail
            mail_domain = config.services.nextcloud.hostName;
            #mail_smtpmode = "smtp";
            # TODO reverse proxy
            #overwriteprotocol = "https"; # TODO reverse proxy
            #trusted_proxies = singleton ""; # TODO reverse proxy
            # TODO SSO
            #hide_login_form = true;
          };
          #webfinger = true; # TODO think about
        };
        x-banananetwork = {
          useable.enable = true;
          vmCommon.enable = true;
        };
      }
    )

    # hardware
    outputs.nixosProfiles.pveGuest

    # installation state
    {
      system.stateVersion = "24.05";
      x-banananetwork.vmDisko = {
        generation = "ext4-1";
        mainDiskName = "main";
      };
    }

  ];
  system = "x86_64-linux";
}
