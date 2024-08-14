{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.x-banananetwork.frontend;
in
{


  options = {

    x-banananetwork.frontend = {

      enable = lib.mkEnableOption "frontend specific settings (highly opionated / customized)";

      convertable = lib.mkEnableOption "convertable specific settings";

      username = lib.mkOption {
        description = "username of ego-centric single main primary user";
        type = lib.types.str;
        default = "zocker";
        example = "username";
      };

    };

  };


  config = lib.mkIf cfg.enable {


    # TODO copy modem-manager overlay (for now)


    # NixOS configuration


    console = {
      useXkbConfig = true;
    };


    environment = {

      pathsToLink = [
        "/share/zsh" # required for Home-Manager ZSH autocompletion, see https://github.com/nix-community/home-manager/blob/e1391fb22e18a36f57e6999c7a9f966dc80ac073/modules/programs/zsh.nix#L353
      ];

      plasma6.excludePackages = with pkgs.kdePackages; [
        baloo # do not need an indexer, which runs at arbitarily times
      ];

    };


    hardware = {

      bluetooth = {
        enable = true;
        powerOnBoot = true;
      };

      graphics.required = true;

      opengl = {
        enable = true;
        driSupport = true;
      };

      usb-modeswitch.enable = true; # for specific WLAN/WWAN cards

    };


    home-manager = {

      useGlobalPkgs = true;
      useUserPackages = true;

      extraSpecialArgs = {
        nixosConfig = config;
      };
      users."${cfg.username}" = import ./home.nix;

    };


    networking = {

      firewall = {
        trustedInterfaces = with lib.lists; flatten [
          (optional config.services.tailscale.enable "tailscale0")
        ];
      };

      networkmanager.enable = true;

      nftables.enable = true;

    };


    nix.settings = {
      builders-use-substitutes = lib.mkDefault true;
    };


    programs = {

      firefox = {
        enable = true;
        policies = {
          Cookies = {
            Behavior = "reject-tracker-and-partition-foreign";
            BehaviorPrivateBrowsing = "reject-tracker-and-partition-foreign";
            Locked = true;
          };
          DisablePocket = true;
          EnableTrackingProjection = {
            Value = true;
            Locked = true;
            Cryptomining = true;
            Fingerprinting = true;
          };
          EncryptedMediaExtensions = {
            Enabled = true;
          };
          ExtensionSettings = {
            "uBlock0@raymondhill.net" = {
              installation_mode = "force_installed";
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
            };
            "7esoorv3@alefvanoon.anonaddy.me" = {
              # TODO probably just for a test
              installation_mode = "allowed";
            };
          };
          FirefoxHome = {
            Search = true;
            TopSites = true;
            SponsoredTopSites = false;
            Highlights = false;
            Pocket = false;
            SponsoredPocket = false;
            Snippets = true;
            Locked = true;
          };
          HttpsOnlyMode = "enabled";
          OfferToSaveLogins = false;
          SearchEngines = {
            # TODO setting search engines here only works on ESR
            Default = "DuckDuckGo";
          };
        };
        preferences = {
          "browser.startup.page" = 3; # restore previous session
          "browser.search.suggest.enabled" = false;
          "browser.urlbar.showSearchSuggestionsFirst" = false;
        };
      };

      gamemode = {
        enable = true;
        enableRenice = true;
        settings = {
          general = {
            renice = 5;
          };
        };
      };

      kdeconnect = {
        enable = true;
        package = pkgs.kdePackages.kdeconnect-kde; # for Plasma 6 & higher
      };

      light.enable = true;

      mosh = {
        # requires testing & so on
        enable = true;
        openFirewall = false; # technically requires this
      };

      nix-index = {
        enable = true;
      };

      rust-motd = {
        enable = true;
        order = [
          "banner"
          "uptime"
          "memory"
          "filesystems"
          "service_status"
          "last_login"
        ];
        settings = {
          banner =
            let
              hostname = config.networking.hostname;
              figlit = lib.runCommandLocal "echo '${hostname}' | ${pkgs.figlit}/bin/figlit -f slant > $out";
            in
            {
              color = lib.mkDefault "red";
              command = "cat ${figlit}";
            };
          filesystems = {
            root = "/";
            home = "/home";
            nix = "/nix";
          };
          last_login = {
            "${cfg.username}" = 3;
          };
          memory.swap_pos = "beside";
          service_status = {
            # TODO automate
            Tailscale = "tailscale.service";
          };
          uptime.prefix = "Up";
        };
      };

      steam = {
        enable = true;
        localNetworkGameTransfers.openFirewall = true;
        remotePlay.openFirewall = true;
      };

      tmux = {
        plugins = with pkgs.tmuxPlugins; [
          # custom plugins, TODO overlay
          mkTmuxPlugin
          {
            pluginName = "zocker";
            version = "unstable-2019-11-07";
            src = fetchFromGitea {
              host = "git.banananet.work";
              owner = "zocker";
              repo = "tmux-custom";
              rev = "f9bafb8b29fad4b1ba77994540f069a49bb10e38";
              sha256 = ""; # TODO
            };
          }
        ];
      };

      usbtop.enable = true;

      wireshark.enable = true;

      ydotool.enable = true;

    };


    security = {

      rtkit.enable = lib.mkIf config.services.pipewire.enable true;

    };


    services = {

      fail2ban = {
        # SSH managed by default
        enable = true;
        ignoreIP = lib.mkIf config.services.tailscale.enable [
          "100.64.0.0/10"
          "fd7a:115c:a1e0::/96"
        ];
        bantime = "10m";
        bantime-increment = {
          enable = true;
          maxtime = "48h";
          overalljails = true;
        };
      };

      hardware = {
        bolt.enable = true; # Thunderbolt
      };

      openssh = {
        enable = true;
        authorizedKeysInHomedir = true;
        authorizedKeysOnly = true;
        openFirewall = true;
        settings = {
          PermitRootLogin = "no";
        };
      };

      pipewire = {
        enable = true;
        audio.enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      printing = {
        enable = true;
        cups-pdf = {
          enable = true;
        };
        stateless = true; # test
      };

      tailscale = {
        enable = true;
        useRoutingFeatures = "client";
        extraUpFlags = [
          # TODO with next upgrade, use extraSetFlags
          "--operator=${cfg.username}"
          "--accept-dns=true"
          "--accept-routes=true"
          "--exit-node=prox-vm134"
          "--exit-node-allow-lan-access=true"
        ];
      };

      udisks2 = {
        enable = true;
      };

      xserver = {
        enable = true;
        xkb = {
          layout = "de";
          variant = "neo_qwertz";
        };
      };

    };


    users = {

      users."${cfg.username}" = {
        description = "${cfg.username}";
        extraGroups = with lib.lists; flatten [
          (optional cfg.services.networkmanager.enable "networkmanger")
          "wheel"
        ];
        isNormalUser = true;
        openssh.authorizedKeys.keys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAEAQDPRH3HSoCpoeqsovMuHOMvFxRFnCTxRIM2mUlAHo+Ef72F7103OeqwgL59rEFOWD8XS3sJhJ/k/dkLvvrANMDWiu5ofaJgA/SAwZzeC4Nh+1r+NWvuwlqvMWvka6Jg0U7l8ZLXD6s9Mmc7+kt4HYnF7xMcuaYBXyCj43eSG+EaiPDMW1Td3MdpzSYI6TvZN+iuhzpWNEemxAouyJvuKFggJM2XhrMHaPufabMIxVjekmMXce4uTeJ6ySaeXrIKEYofkvTC/3dqHQRlTvDGX0Jiy2T2CxX+24EdWlFdxWYBN0mPhimvwfdIynOUsvqn/1JTtj5JnYVG0MCygTUi9xJ2/0Djx+ecbbUXSROtUN+V4MHVUrg/43nkTBPVW5mRHQPpb42MeHw2AXbLJEXASdRivaJ9bpIffvGD11jiMrIKDS0Hh7nek0Y0qoGuT/04O/fZSbJiyRQqrk6FZNWzwO4xfUhD8oKjGeAypjJlOty3Krc4ivE1IzE1I4ELKRTZYt2pJln1nHCd/9ELik54JYm+viitAa/yhU4Rg+Qhhtzq5rw6MonUfhLRgmvt2oq4JQWlqFz/qXEdtx3OOKMNZDbzlbFzDRAgP/Jqt7sx2QvivKI5kGpmlk9NXKaH/ucpTFbOkGFcx/bLOov6YfyrrRbwqHi7ZkUPT2BCo5KWvjr/cM5sRQc6Qs+aXD5Bye1Nd3SWMOj1izXd36RxCBqtfzXi5rkPE59qlB7gJ0Q1I49C1WyKUgd15Aw7CubHLpKZRXu8ko5xJ3JQhe15lIrLqMUUATb45DIrsVb3kueA5v8AMSiJkFhyxAjgvZ9V9+zCp8ElCBsjdqZb5/meu44pM/SBlpcntTFb/5BEFhjxdBEXoV6j0ZvkhcLcfWcR8rRnVpoK0CXzF5/xMCWxxM/OUfQ9xUKs0JdhDBWqhK0UWc1dCi48g9FTYXXApfoN/I52ec/3nHHj22FucIePsViw7+AOJm42DO9RJGQBIqRquasrH5uuJqEAufYFr4jSQCWPvdjBhCJIOGNHiu3jRjuEaIUoqH2fNDth69gUok588JvRypM7no2KpdMHvQdgpvqPU0Nuvm4/xnIhmu6jsamoHDObSLj2fagmzwptd5qw1rlqzwMfYtRX3Oj1NQW4qbE+bDozav4d9Pu243gn71ybmsJ5awGHAW/fW0nL5gsYhh9VNefY7Nst4+/KQZBDHppJZY+Cok9yUcnOVjH3qZFQTvIuljkk6IhCjgP5lfELUg3EIimADSJT9gnzE1jfs95CZTwFUhIXucC3CwYnIlPUPSU2DaS0hfopYeiBMxX4A7xvdUohOcY+cbnPHu8HtKIzYWsVg28gLaA+8YDXMHNoyaaD zocker Backup Key 2018-05-28"
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDGKs41V0h0S4cXtodCUwyY7mKk2sMVdTOu2OKm9a1tT24rk2q3khVb+GkS5HetN54qDbylmxBk4egX46jizAsDh1DZnxE2AKTYK2fXrYAFgHZR++Gpjw6pUeFi//gNUh8XHT/5xFlYO5ftysIB4FEBED8Epy3pET1OvXI9/RSppmeQ2yB+cI7gMHDAqrlzdlXkqK1rNFihFtSF4u12b1Bze5tAON+QFDHbkyN+pvj2b2pZ/3FcBb+fvVqZAlM0qEFiRoz7+fYYvZBqFL6OeYvIlas9FcJzycxX9TbVPsfjBlKya0v3MA+LcEOGPTwUnva9og8WQZAuPB0OKkMA46wyw+XwWJvOlIplt6OnYrT8nZ7J+gJGDDGMzCx8jckojoNBPiir0DJFaOhiPsJeW/3LW6yQib8OfgQ6R6RqUmEEKgjcM1tdnZxsrYGtF2q63ZcL4DB24nvGcLAw77Gyi9F0FU4H1uf096NIPM5Rmgvw48ZNkg4+kJ2PsVFO5H+wAmV23/dmIBz12Qltx+l5N9rSwyrIVplVulpd3B2lLm+Av6Jhn65qc5uEBH/0FyBz+HoXI9OBhFRRV+q5LqfTXrjWC8LhljjKHzWo4pPsQJp5TKOsoSLconeQG+ByP/iy1wfmXh+MLTK191Dw4Th2hZUHEMlek7y9SIKm/RY2buPxuQ== 93e1bd26f6b02fb@keys.banananet.work"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBdtHoYx74Dp2P/Th72JpY/vnSL8LUDG10HGoU+I162 zocker@thinkie.khitomer.banananet.work 2019-06-04"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ322iTs4HagYWO5C/O8t2smxBOJNW68amar99H7f0kq zocker@zockerpc 2018-07-22"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAEaWqcgeNh3BjyDXCg0DQfbuPg5VLVYlt8ucYu7VZNr zocker@x13yz 2024-07-04"
        ];
        packages = with pkgs; lib.lists.flatten [
          kdePackages.kate
          (lib.lists.optional cfg.convertable [
            maliit-keyboard # on-screen keyboard (should just work, see https://discuss.kde.org/t/how-to-enable-virtual-keyboard-included-in-kde/264/2)
          ])
        ];
      };

    };


    x-banananetwork = {

      allCommon.enable = true;
      autoUnfree.enable = true;
      hwCommon.enable = true;
      vmCommon.enable = false;
      useable.enable = true;

    };


    # TODO move KDE Connect to same level as plasma6 (either nixos or hm)
    # TODO wishlist:
    # - enable & disable touch keyboard automatically based on convertable status
    # - programs.captive-browser
    # - https://github.com/cynicsketch/nix-mineral (NixOS hardening)
    # - programs.mepo
    # - programs.autojump
    # - programs.yubikey-touch-detector


  };


}
