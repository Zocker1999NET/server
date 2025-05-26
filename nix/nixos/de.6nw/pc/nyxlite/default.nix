{ lib, outputs, ... }:
let
  inherit (lib.lists) singleton;
in
{
  modules = [

    # system config
    {
      # TODO cage with chromium (or other, more suitable module) for Grocy
    }

    # Spotify appliance
    (
      { config, pkgs, ... }:
      {
        console.useXkbConfig = true;
        environment.systemPackages = with pkgs; [
          spotify
        ];
        networking = {
          networkmanager.enable = true;
          nftables.enable = true;
        };
        hardware = {
          bluetooth.enable = true;
          graphics.required = true;
        };
        programs = {
          firefox = {
            enable = true;
            policies = {
              BlockAboutAddons = true;
              BlockAboutConfig = true;
              BlockAboutProfiles = true;
              BlockAboutSupport = true;
              Cookies = {
                Behavior = "reject-tracker-and-partition-foreign";
                BehaviorPrivateBrowsing = "reject-tracker-and-partition-foreign";
                Locked = true;
              };
              DisableFirefoxAccounts = true;
              DisableFirefoxStudies = true;
              DisableFormHistory = true;
              DisableMasterPasswordCreation = true;
              DisableProfileImport = true;
              DisableProfileRefresh = true;
              DisablePocket = true;
              DisableSetDesktopBackground = true;
              DisableTelemetry = true;
              # TODO DontCheckDefaultBrowser = true; when this is configured
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
                      Installing more add-ons disallowed.
                    '';
                    installation_mode = "blocked";
                  };
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
          };
        };
        security = {
          rtkit.enable = lib.mkIf config.services.pipewire.enable true;
        };
        services = {
          cinnamon.apps.enable = false;
          displayManager = {
            defaultSession = "cinnamon-wayland";
            autoLogin = {
              enable = true;
              user = "music";
            };
          };
          getty.helpLine = "IPs:  \\4  \\6";
          getty.dynamicHelpLine = {
            sshPublicHostKey.enable = true;
          };
          openssh.enable = true;
          pipewire = {
            enable = true;
            audio.enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;
            pulse.enable = true;
          };
          # target for DM: lightweight, but user-friendly for normies
          xserver = {
            enable = true;
            desktopManager.cinnamon.enable = true;
            displayManager.lightdm = {
              enable = true;
            };
            xkb.layout = "de"; # non neo for user-friendlyness
          };
        };
        users = {
          mutableUsers = false;
          users = {
            "music" = {
              description = "Music User";
              isNormalUser = true;
              openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
            };
            ${config.x-banananetwork.userName} = {
              description = config.x-banananetwork.userName;
              extraGroups = [ "wheel" ];
              hashedPassword = "$y$j9T$MdvgnTFGyCnZ.sLhXK7.w.$VkI6NqE7ZaN7xULmOrYCvgC6Sot19S0RWf.FmrOaLnC";
              isNormalUser = true;
              openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
            };
            root.openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
          };
        };
        x-banananetwork = {
          autoUnfree = {
            enable = true;
            names = [
              "spotify"
            ];
          };
          useable.enable = true;
        };
      }
    )

    # host config
    {
      networking.domain = "pc.6nw.de";
      networking.hostName = "nyxlite";
    }

    # hardware (Microsoft Surface 3)
    outputs.nixosProfiles.blade
    {
      # to find boot drive
      boot.initrd.availableKernelModules = [
        "mmc_block"
        "sdhci-acpi"
      ];
      # TODO (maybe) custom linux-surface kernel patches
      hardware = {
        cpu.type = "intel";
        graphics.intel.enable = true;
      };
    }

    # state
    {
      system.stateVersion = "24.05";
      x-banananetwork.vmDisko = {
        generation = "ext4-swap-1";
        mainDiskName = "main";
      };
    }

  ];
  system = "x86_64-linux";
}
