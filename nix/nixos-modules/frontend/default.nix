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
      };

      light.enable = true;

      mosh = {
        # requires testing & so on
        enable = true;
        openFirewall = false; # technically requires this
      };

      nix-index = {
        # seems to much hazzle to setup & use for now
        enable = false;
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
              hostName = config.networking.hostName;
              figlet = pkgs.runCommandLocal "static-figlet-${hostName}" { } ''
                echo '${hostName}' | ${pkgs.figlet}/bin/figlet -f slant > $out
              '';
            in
            {
              color = lib.mkDefault "red";
              command = "cat ${figlet}";
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
          (mkTmuxPlugin {
            pluginName = "zocker";
            version = "unstable-2019-11-07";
            src = pkgs.fetchFromGitea {
              domain = "git.banananet.work";
              owner = "zocker";
              repo = "tmux-custom";
              rev = "f9bafb8b29fad4b1ba77994540f069a49bb10e38";
              hash = "sha256-v0zkIqYnFYDcwgkjrRbOH2AXWUm1RXvFbcbQB/N1lzo=";
            };
          })
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

      desktopManager.plasma6 = {
        enable = true;
      };

      displayManager.sddm = {
        enable = true;
      };

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

      pcscd.enable = true;

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
          (optional config.networking.networkmanager.enable "networkmanger")
          "wheel"
        ];
        isNormalUser = true;
        openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
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

      autoUnfree = {
        enable = true;
        # TODO merge with nixos-modules/frontend/home.nix
        packages = with pkgs.mpvScripts; [
          evafast
        ];
      };

      hwCommon.enable = lib.mkDefault true;
      privacy.enable = lib.mkDefault true;
      useable.enable = true;

    };


    # TODO wishlist:
    # - enable & disable touch keyboard automatically based on convertable status
    # - programs.captive-browser
    # - https://github.com/cynicsketch/nix-mineral (NixOS hardening)
    # - programs.mepo
    # - programs.autojump
    # - programs.yubikey-touch-detector


  };


}
