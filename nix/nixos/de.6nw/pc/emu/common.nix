{ lib, ... }:
let
  inherit (builtins)
    attrNames
    attrValues
    concatStringsSep
    mapAttrs
    ;
  inherit (lib.lists) flatten optional singleton;
  inherit (lib.strings) escapeShellArg;
  inherit (lib.trivial) flip pipe;
  gameUser = "gamer";
in
{
  imports = [
    # Dolphin Networking
    (
      { config, ... }:
      {
        # https://ladis.cloud/blog/posts/dolphin-broadband-adapter.html
        systemd.network = {
          links."10-ethernet".linkConfig = {
            MACAddressPolicy = lib.mkDefault "persistent";
            NamePolicy = ""; # -> use Name=
            Name = "eno1";
            AlternativeNamesPolicy = "mac slot path onboard";
          };
          netdevs = {
            "10-dolphin-tap" = {
              netdevConfig = {
                Kind = "tap";
                Name = "Dolphin0";
              };
              tapConfig = {
                User = gameUser;
              };
            };
            "10-dolphin-bridge" = {
              netdevConfig = {
                Kind = "bridge";
                Name = "br0";
                MACAddress = config.systemd.network.links."10-ethernet".matchConfig.PermanentMACAddress;
              };
            };
          };
          networks = {
            # hacky / conflicts with normal config
            "10-dolphin-tap" = {
              matchConfig.Name = "Dolphin*";
              networkConfig.Bridge = "br0";
            };
            "10-dolphin-ethernet" = {
              matchConfig.Name = "eno1"; # hardcoded
              networkConfig.Bridge = "br0";
            };
            "10-bridge-internet" = {
              matchConfig.Name = "br0";
              networkConfig = {
                DHCP = "ipv4";
                IPv6AcceptRA = true;
              };
            };
          };
        };
      }
    )
    # Gaming Auto Login
    (
      { pkgs, ... }:
      {
        environment = {
          # TODO extract retroarch prepare script
          loginShellInit =
            let
              raDir = "/home/gamer/.config/retroarch";
              chtDir = "${raDir}/cheats";
              chtZip = "${chtDir}/cheats.zip";
              cheatMap = {
                Mesen = [
                  "Nintendo - Family Computer Disk System"
                  "Nintendo - Nintendo Entertainment System"
                ];
                SameBoy = [
                  "Nintendo - Game Boy"
                  "Nintendo - Game Boy Color"
                ];
                "bsnes-hd beta" = singleton "Nintendo - Super Nintendo Entertainment System";
                "Mupen64Plus-Next" = [
                  "Nintendo - Nintendo 64"
                  "Nintendo - Nintendo 64 (Aleck64)"
                  "Nintendo - Nintendo 64 (Unreleased)"
                  "Nintendo - Nintendo 64 (iQue)"
                ];
                mGBA = singleton "Nintendo - Game Boy Advance";
                melonDS = singleton "Nintendo - Nintendo DS";
              };
            in
            ''
              if [[ "$(tty)" = "/dev/tty1" ]]; then
                if [[ -e ${escapeShellArg chtZip} ]]; then
                  # TODO extract cheats.zip
                  echo "Setup cheat mapping"
                  ${
                    pipe cheatMap [
                      (mapAttrs (
                        emu: sources:
                        let
                          emuE = escapeShellArg "${chtDir}/${emu}";
                        in
                        #rm -rf ${emuE}
                        ''
                          mkdir -p ${emuE}
                          ${pipe sources [
                            (map (x: "tar -C ${escapeShellArg "${chtDir}/${x}"} -cf - . | tar -C ${emuE} -xf -"))
                            (concatStringsSep "\n")
                          ]}
                        ''

                      ))
                      attrValues
                      (concatStringsSep "\n")
                    ]
                  }
                  echo "Cheat mapping complete"
                fi
                exec gamescope -- retroarch --menu --fullscreen
              fi
            '';
        };
        services.getty.autologinUser = "gamer";
        programs = {
          gamescope = {
            enable = true;
            capSysNice = true;
          };
          # TODO maybe Steam
        };
        /*
          services.displayManager = {
            autoLogin = {
              enable = true;
              user = "gamer";
            };
            defaultSession = "none+i3";
          };
          services.xserver = {
            enable = true;
            desktopManager.xterm.enable = true;
            windowManager.i3 = {
              enable = true;
              extraPackages = with pkgs; [
                dmenu
                i3status
              ];
            };
          };
        */
      }
    )
    # Mount Games
    {
      boot.supportedFilesystems.cifs = true;
      fileSystems."/mnt/Games" = {
        device = "//10.11.11.72/Games";
        fsType = "cifs";
        options = [
          # this line prevents hanging on network split
          "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s"
          "username=nobody,guest"
        ];
      };
    }
    # Gaming Setup
    (
      { config, pkgs, ... }:
      {
        environment.systemPackages = singleton pkgs.dolphin-emu;
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
        };
        services.joycond.enable = false; # fuck you
        users.users.${gameUser} = {
          description = "Gamer User";
          extraGroups = flatten [
            (optional config.programs.gamemode.enable "gamemode")
            (optional config.networking.networkmanager.enable "networkmanger")
            (optional config.programs.light.enable "video")
          ];
          isNormalUser = true;
        };
      }
    )
    {
      nixpkgs.permitInsecurePackagesUntil = {
        # mbedtls_2 was marked insecure because it is unmaintained
        # see https://github.com/NixOS/nixpkgs/commit/bef41c7425e49b5b20a5124b4f21cd633dfc90e9
        # but it is already unmaintained since 2025-03-24,
        # see https://github.com/Mbed-TLS/mbedtls/releases/tag/mbedtls-2.28.10
        # and in my case it is primarily used by dolphin-emu, hence I think I can ignore this for now
        "mbedtls-2.28.10" = "25.05";
      };
      home-manager.users.${gameUser} =
        {
          config,
          osConfig,
          pkgs,
          ...
        }:
        {
          home.stateVersion = osConfig.system.stateVersion;
          programs.retroarch = {
            enable = true;
            cores = with pkgs.libretro; [
              # as recommended by https://emulation.gametechwiki.com
              mesen # 1983 NES
              sameboy # 1989 GB
              bsnes-hd # 1990 SNES
              mupen64plus # 1996 N64 (multi, maybe for SNES too; not for NES)
              sameboy # 1998 GBC
              mgba # 2001 GBA
              dolphin # 2001 GCN
              melonds # 2004 NDS (+NDSi)
              dolphin # 2006 Wii
            ];
          };
          # TODO:
          # - Input > Menu Controls > All Users Control Menu = true
          # - Input > Pause Content when Controllers disconnect
        };
    }
    {
      services.logind = {
        suspendKey = "poweroff";
        rebootKey = "reboot";
        powerKey = "poweroff";
        hibernateKey = "poweroff";
        lidSwitch = "ignore";
      };
    }
    # UI setup
    (
      { pkgs, ... }:
      {
        console.useXkbConfig = true;
        documentation.nixos.includeAllModules = false; # efficiency
        environment = {
          plasma6.excludePackages = with pkgs.kdePackages; [
            baloo # do not need an indexer, which runs at arbitarily times
          ];
          systemPackages = with pkgs; [
            bluetuith # bluetooth UI
          ];
        };
        hardware = {
          bluetooth.enable = true;
          graphics.required = true;
          #steam-hardware.enable = true;
          usb-modeswitch.enable = true;
        };
        #x-banananetwork.autoUnfree.packages = singleton pkgs.steamPackages.steam; # for steam-hardware
        networking = {
          nftables.enable = true;
          useNetworkd = true;
        };
        programs = {
          gamemode = {
            enable = true;
            enableRenice = true;
            settings = {
              general = {
                renice = 5;
              };
            };
          };
          light.enable = true;
        };
        security.rtkit.enable = true;
        services = {
          openssh.enable = true;
          pipewire = {
            enable = true;
            audio.enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;
            pulse.enable = true;
          };
          xserver.xkb = {
            layout = "de";
          };
        };
        x-banananetwork = {
          allCommon.enable = true;
          autoUnfree.enable = true;
          privacy.enable = true;
          useable.enable = true;
        };
      }
    )
    # managament access
    (
      { config, lib, ... }:
      {
        services.openssh.enable = true;
        users = {
          mutableUsers = false; # TODO move that (maybe to common?)
          users.${config.x-banananetwork.userName} = {
            description = config.x-banananetwork.userName;
            extraGroups = singleton "wheel";
            hashedPassword = "$y$j9T$MdvgnTFGyCnZ.sLhXK7.w.$VkI6NqE7ZaN7xULmOrYCvgC6Sot19S0RWf.FmrOaLnC";
            isNormalUser = true;
            openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
          };
          users.root.openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
        };
      }
    )
  ];
}
