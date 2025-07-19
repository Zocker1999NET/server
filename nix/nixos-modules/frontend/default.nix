{
  config,
  lib,
  pkgs,
  ...
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

    console = {
      useXkbConfig = true;
    };

    # TODO reenable, taskwarrior:///d3d19597-a834-4030-9f42-4e8fac56daac
    documentation.nixos.includeAllModules = false; # full manual aids NixOS dev

    environment = {

      pathsToLink = [
        "/share/zsh" # for ZSH completion
      ];

      plasma6.excludePackages = with pkgs.kdePackages; [
        baloo # do not need an indexer, which runs at arbitarily times
      ];

      # NOTE: only define packages here required for system integrations, for limited exposure
      systemPackages = with pkgs; [
        kdePackages.kio-fuse # for dolphin to mount remote filesystems via FUSE
        kdePackages.kio-extras # extra protocols support (sftp, fish and more)
      ];

    };

    hardware = {

      bluetooth = {
        enable = true;
        powerOnBoot = true;
      };

      gpgSmartcards.enable = true; # scdaemon

      graphics.required = true;

      logitech.wireless = {
        enable = true;
        enableGraphical = true;
      };

      sane = {
        enable = true;
        openFirewall = true;
      };

      usb-modeswitch.enable = true; # for specific WLAN/WWAN cards

    };

    home-manager = {

      useGlobalPkgs = true;
      useUserPackages = true;

      users."${cfg.username}" = import ./home.nix;

    };

    networking = {

      firewall = {
        trustedInterfaces =
          with lib.lists;
          flatten [ (optional config.services.tailscale.enable "tailscale0") ];
      };

      networkmanager.enable = true;

      nftables.enable = true;

    };

    nix.settings = {
      builders-use-substitutes = lib.mkDefault true;
    };

    programs = {

      ausweisapp = {
        enable = true;
        openFirewall = true;
      };

      captive-browser = {
        enable = true;
        bindInterface = true;
      };

      firefox = {
        enable = true;
        policies = {
          Cookies = {
            Behavior = "reject-tracker-and-partition-foreign";
            BehaviorPrivateBrowsing = "reject-tracker-and-partition-foreign";
            Locked = true;
          };
          DisablePocket = true;
          DisableSetDesktopBackground = true;
          EnableTrackingProjection = {
            Value = true;
            Locked = true;
            Cryptomining = true;
            Fingerprinting = true;
          };
          EncryptedMediaExtensions = {
            Enabled = true;
          };
          ExtensionSettings =
            let
              # TODO upstream
              addon = id: opts: {
                name = id;
                value = {
                  default_area = "menupanel";
                  installation_mode = "force_installed";
                  install_url = "https://addons.mozilla.org/firefox/downloads/latest/${id}/latest.xpi";
                } // opts;
              };
              enrichAddons = id: opts: if id == "*" then opts else (addon id opts).value;
            in
            builtins.mapAttrs enrichAddons {
              "*" = {
                blocked_install_message = ''
                  Please add add-ons by changing your NixOS configuration.
                '';
                installation_mode = "blocked";
              };
              # Cast Kodi
              "castkodi@regseb.github.io" = { };
              # DeArrow
              "deArrow@ajay.app" = { };
              # KeePassXC-Browser
              "keepassxc-browser@keepassxc.org" = {
                default_area = "navbar";
              };
              # LibRedirect
              "7esoorv3@alefvanoon.anonaddy.me" = { };
              # Link Gopher
              "linkgopher@oooninja.com" = { };
              # ProtonDB for Steam
              "{30280527-c46c-4e03-bb16-2e3ed94fa57c}" = { };
              # Refined GitHub
              "{a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad}" = { };
              # Request Control
              # TODO alternative taskwarrior:///31217b57-efa9-44b5-874b-6ee597e95c9a
              "{1b1e6108-2d88-4f0f-a338-01f9dbcccd6f}" = {
                default_area = "navbar";
              };
              # SponsorBlock
              "sponsorBlocker@ajay.app" = { };
              # SteamDB
              "firefox-extension@steamdb.info" = { };
              # Tab Stash
              # TODO replace, taskwarrior:///544aa57e-584d-4ea5-b55d-a78dab0df7be
              "tab-stash@condordes.net" = {
                default_area = "navbar";
              };
              # Tabliss
              "extension@tabliss.io" = { };
              # uBlock Origin
              # TODO use policies, taskwarrior:///5f7649da-66aa-4355-bc7d-119c02275e56
              "uBlock0@raymondhill.net" = {
                default_area = "navbar";
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
          HttpAllowList = [
            "http://hatoria:8088"
            "http://penny:8123"
          ];
          HttpsOnlyMode = "force_enabled";
          NetworkPrediction = false;
          NoDefaultBookmarks = true;
          OfferToSaveLogins = false;
          OverrideFirstRunPage = "";
          OverridePostUpdatePage = "";
          Permissions = {
            Autoplay = {
              Default = "block-audio-video";
            };
            Location = {
              BlockNewRequests = true;
              Locked = true;
            };
          };
          PopupBlocking = {
            Allow = [
              "https://app.roll20.net"
              # placeholder for more
            ];
            Default = true;
            Locked = true;
          };
          PostQuantumKeyAgreementEnabled = true;
          # Preferences set by ..preferences below
          PrimaryPassword = true;
          SearchBar = "unified";
          SearchEngines = {
            # TODO setting search engines here only works on ESR
            Default = "DuckDuckGo";
          };
          ShowHomeButton = false;
          UserMessaging = {
            ExtensionRecommendations = false;
            FeatureRecommendations = false;
            UrlbarInterventions = false;
            SkipOnboarding = true;
            MoreFromMozilla = false;
            Locked = true;
          };
        };
        preferences = {
          "accessibility.typeaheadfind.flashBar" = 0;
          "browser.aboutConfig.showWarning" = false;
          "browser.language.detectLanguage" = false;
          "browser.search.suggest.enabled" = false;
          "browser.startup.page" = 3; # restore previous session
          "browser.urlbar.showSearchSuggestionsFirst" = false;
          "print.more-settings.open" = true;
          "security.insecure_connection_text.enabled" = true;
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

      # TODO fails as of now & creates CPU spikes every 15 minutes
      # journalctl --since="2024-08-21 10:00" --until="2024-08-21 20:20" -u rust-motd
      rust-motd = lib.mkIf false {
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
                echo '${hostName}' | ${lib.getExe pkgs.figlet} -f slant > $out
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
              # TODO revert to custom Git when up again
              #domain = "git.banananet.work";
              #owner = "zocker";
              domain = "github.com";
              owner = "Zocker1999NET";
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

      ddccontrol.enable = true;

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
        # cups
        enable = true;
        cups-pdf = {
          enable = true;
        };
        drivers = with pkgs; [
          brlaser # for some Brother
          gutenprint
          gutenprintBin
          hplip
          postscript-lexmark
          splix # for SPL (Samsung Printer Language)
        ];
        enableAutoDiscovery = true;
        stateless = true; # TODO test
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

    specialisation =
      let
        kernelSpecial = pkg: { configuration.boot.kernelPackages = pkg; };
        mapAttrs = builtins.mapAttrs (name: kernelSpecial);
      in
      mapAttrs {
        # TODO enable all kernels with faster build machine
        # TODO experiment with gaming kernels
        # gaming/performance kernels
        #linux_lqx = pkgs.linuxPackages_lqx;
        #linux_xanmod_latest = pkgs.linuxPackages_xanmod_latest;
        #linux_xanmod_stable = pkgs.linuxPackages_xanmod_stable;
        #linux_zen = pkgs.linuxPackages_zen;
        # older kernels (for cases like again: https://github.com/NixOS/nixpkgs/issues/330685)
        # list of supported kernels taken from https://www.kernel.org/releases.html
        #linux_6_6 = pkgs.linuxPackages_6_6;
        linux_6_1 = pkgs.linuxPackages_6_1;
        #linux_5_15 = pkgs.linuxPackages_5_15;
      };

    system = {
      extraDependencies = with pkgs; [
        ## (caching for ~/projects/pferd), TODO remove or integrate sometime
        pferd
        rsnapshot
      ];
    };

    users = {

      users.${cfg.username} = {
        description = cfg.username;
        extraGroups =
          with lib.lists;
          flatten [
            # TODO make user groups an assertion
            (optional config.programs.gamemode.enable "gamemode")
            (optional config.services.printing.enable "lpadmin")
            (optional config.networking.networkmanager.enable "networkmanger")
            (optional config.hardware.sane.enable "scanner")
            (optional config.programs.light.enable "video")
            "wheel"
          ];
        isNormalUser = true;
        openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
        packages =
          with pkgs;
          lib.lists.flatten [
            kdePackages.kate
            (lib.lists.optional cfg.convertable [
              maliit-keyboard # on-screen keyboard (should just work, see https://discuss.kde.org/t/how-to-enable-virtual-keyboard-included-in-kde/264/2)
            ])
          ];
      };

    };

    virtualisation = {

      podman = {
        enable = true;
        compose.enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
      };

    };

    x-banananetwork = {

      allCommon.enable = true;

      autoUnfree = {
        enable = true;
        packages = with pkgs.mpvScripts; [
          # TODO merge with nixos-modules/frontend/home.nix
          evafast
        ];
      };

      privacy.enable = lib.mkDefault true;
      useable.enable = true;

    };

    # TODO wishlist:
    # - lockdown more (at least disable systemd-boot.editor OR enable TPM PCR checks)
    # - enable & disable touch keyboard automatically based on convertable status
    # - https://github.com/cynicsketch/nix-mineral (NixOS hardening)
    # - programs.mepo
    # - programs.autojump
    # - programs.yubikey-touch-detector

  };

}
