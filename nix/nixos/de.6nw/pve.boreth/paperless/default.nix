{ lib, outputs, ... }:
let
  inherit (lib.modules) mkForce;
in
{
  # manual work required on first launch:
  # - setup admin user

  modules = [

    # Paperless: configure automatic consumption settings (TODO extend as needed)
    # - TODO: configure barcode settings (https://docs.paperless-ngx.com/configuration/#barcodes)
    {
      services.paperless = {
        settings = {
          PAPERLESS_CONSUMER_DISABLE = "true"; # for now
          PAPERLESS_CONSUMER_ENABLE_COLLATE_DOUBLE_SIDED = "false"; # I have an DADF
        };
      };
    }

    # Paperless: consumption parsing
    {
      services.paperless = {
        configureTika = true; # for parsing "Office" documents & e-mails themselves
        settings = {
          PAPERLESS_OCR_MODE = "skip"; # skip OCR if text is already present
          PAPERLESS_OCR_OUTPUT_TYPE = "pdfa";
        };
      };
    }

    # Paperless: localization settings
    (
      { config, ... }:
      {
        services.paperless.settings = {
          PAPERLESS_DATE_PARSER_LANGUAGES = "de+en";
          PAPERLESS_TIME_ZONE = config.x-banananetwork.localTimeZone; # because documents may more often refer to local time
          PAPERLESS_OCR_LANGUAGE = "deu+eng";
        };
      }
    )

    # Paperless: configuring exposure via nginx
    # - more efficient for static files
    # - use compression on nginx rather paperless
    (
      { config, pkgs, ... }:
      {
        services = {
          nginx = {
            experimentalZstdSettings = true;
            recommendedBrotliSettings = true;
            recommendedGzipSettings = true;
            virtualHosts.${config.services.paperless.domain} = {
              forceSSL = false;
            };
          };
          paperless = {
            configureNginx = true;
            domain = config.networking.fqdnOrHostName;
            settings = {
              PAPERLESS_ENABLE_COMPRESSION = "false";
              # for now, TODO configure to public domain and use https
              PAPERLESS_URL = mkForce "http://[fde3:b424:b5ce:1:be24:11ff:fe9c:8f04]";
            };
          };
        };
      }
    )

    # Paperless: basic service config
    (
      { config, pkgs, ... }:
      {
        services.paperless = {
          enable = true;
          # makes it use a PostgreSQL database (instead of SQLite) and run the database locally
          database.createLocally = true;
          settings = {
            PAPERLESS_AUDIT_LOG_ENABLED = "true";
          };
        };
      }
    )

    # configure data directories on the VM disk
    (
      { config, pkgs, ... }:
      let
        dataMountpoint = config.disko.devices.disk.data.content.partitions.data.content.mountpoint;
      in
      {
        services.paperless.dataDir = "${dataMountpoint}/paperless";
        services.postgresql.dataDir = "${dataMountpoint}/postgresql";
      }
    )

    # config
    (
      { config, pkgs, ... }:
      {
        networking = {
          hostName = "paperless";
          domain = "boreth.pve.6nw.de";
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
      system.stateVersion = "25.11";
      x-banananetwork.vmDisko = {
        generation = "ext4-dualDisk-1";
      };
      disko.devices.disk = {
        main.name = "paperlessMain";
        data.name = "paperlessData";
      };
    }

  ];
  system = "x86_64-linux";
}
