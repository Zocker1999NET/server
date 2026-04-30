{ lib, outputs, ... }:
let
  inherit (lib.modules) mkForce;
in
{
  # manual work required on first launch:
  # - setup admin user

  modules = [

    # Consumption of documents via SMB share (e.g. for autonomous scanning)
    outputs.nixosProfiles.sambaServer
    # TODO use same general module as for nixnas (mind ! for diffs)
    (
      { config, ... }:
      let
        # constants
        userService = "samba-user-config";
        paperlessUser = config.services.paperless.user;
        groupName = "smb"; # group smb required because printer requires access to builtin IPC$
        # service vars
        shareName = "paperless-scanner";
        userName = shareName;
        # derived constants
        secretName = "smb_${userName}";
      in
      {
        services.samba.settings = {
          global = {
            "server min protocol" = mkForce "SMB2_02";
          };
          ${shareName} = {
            path = config.services.paperless.consumptionDir; # !
            browseable = "yes";
            "guest ok" = "no";
            "read only" = "no";
            "valid users" = userName;
            "force user" = paperlessUser;
            "force group" = paperlessUser;
          };
        };
        # ! directory is managed by paperless module
        users.users.${userName} = {
          isSystemUser = true;
          group = groupName;
          # by default, users cannot login (i.e. "nologin" shell & password locked)
          samba.passwordFile = config.secrix.services.${userService}.secrets.${secretName}.decrypted.path;
        };
        # pwgen -s 32 | secr encrypt paperless.boreth.pve.6nw.de nix/nixos/de.6nw/pve.boreth/paperless/smb_paperless-scanner.age
        secrix.services.${userService}.secrets.${secretName}.encrypted.file = ./${secretName}.age;
      }
    )

    # Paperless: QR code & barcode interpretation
    {
      services.paperless.settings = {
        # page separation
        PAPERLESS_CONSUMER_ENABLE_BARCODES = "true";
        # https://github.com/baltpeter/scanprep/blob/master/separator-page.pdf
        PAPERLESS_CONSUMER_BARCODE_STRING = "SCANPREP_SEP";
        # ASN assignment
        PAPERLESS_CONSUMER_ENABLE_ASN_BARCODE = "true";
        PAPERLESS_CONSUMER_ASN_BARCODE_PREFIX = "ASN";
        # required to that my small QR codes can be read
        PAPERLESS_CONSUMER_BARCODE_SCANNER = "ZXING";
      };
    }

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
          PAPERLESS_TASK_WORKERS = 2;
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
        networking.firewall = {
          allowedTCPPorts = [
            config.services.nginx.defaultHTTPListenPort
            config.services.nginx.defaultSSLListenPort
          ];
          allowedUDPPorts = [
            config.services.nginx.defaultSSLListenPort # QUIC
          ];
        };
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
      x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ7qfWfU66S7z8lnFsyX48NygxaM6ngsuIX/YHHnYFTA root@paperless.boreth.pve.6nw.de 2026-04-21";
    }

  ];
  system = "x86_64-linux";
}
