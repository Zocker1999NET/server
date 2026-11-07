# Silverstone old stuff
# purpose: Kodi Media Center (LibreELEC-like appliance)
# Hardware:
# - CPU: Intel Core i5-4590S (Haswell)
# - Memory: 8 GB DDR3
# - Storage: 64 GB SSD
# - Graphics: Intel HD Graphics 4600 (integrated)
{
  inputs,
  lib,
  self,
  ...
}:
let
  nixosHW = inputs.nixos-hardware;

  inherit (builtins) attrNames mapAttrs removeAttrs;
  inherit (lib) types;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) flatten;
  inherit (lib.modules)
    mkAfter
    mkForce
    mkIf
    mkMerge
    ;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) flip pipe;

  cageUser = "cage";
in
{
  modules = [

    (
      { config, pkgs, ... }:
      let
        modes = {

          crunchyroll = {
            services.cage = {
              enable = true;
              webbrowser = {
                enableDRM = true;
                rememberCookies = true;
                url = "https://www.crunchyroll.com/discover";
              };
            };
          };

          kodi = {
            services.kodi = {
              enable = true;
              openFirewall = true; # web interface & event server
              addons = with config.services.kodi.package.packages; [
                invidious
                mediacccde
                sendtokodi
                sponsorblock
              ];
            };
          };

          moonlight = {
            services.cage = {
              enable = true;
              commands = "${pkgs.moonlight-qt}/bin/moonlight";
              options.allowVTSwitching = true;
            };
          };

        };
      in
      {
        options.x-banananetwork.mode = mkOption {
          description = "mode of operation for this device";
          type = types.enum (attrNames modes);
          default = "crunchyroll";
        };
        config = mkMerge (flatten [
          (flip mapAttrsToList modes (name: module: mkIf (config.x-banananetwork.mode == name) module))
          {
            specialisation = pipe modes [
              (mapAttrs (name: _: { configuration.x-banananetwork.mode = name; }))
              # filter out default value, because it is already applied by default
              (flip removeAttrs [ config.x-banananetwork.mode ])
            ];
          }
        ]);
      }
    )

    ({ config, ... }: {
      services.cage = {
        audio = {
          enable = true;
          defaultSinkMatcher."node.name" = "alsa_output.pci-0000_00_03.0.hdmi-stereo";
        };
        commands = mkAfter "systemctl poweroff";
        user = cageUser;
        wlr-randr.HDMI-A-2 = {
          # for Samsung TV, otherwise defaults to 4080x2160, which is defacto not supported by TV
          mode = "3840x2160@30Hz";
          # for readability
          scale = "3";
        };
      };
      users.users.${cageUser} = mkIf (config.services.cage.enable) {
        isNormalUser = true;
        extraGroups = [
          "audio"
          "input"
          "video"
        ];
        description = "Cage user for kiosk mode";
      };
    })

    {
      console.useXkbConfig = true;
      services.xserver.xkb = {
        layout = "de";
      };
    }

    {
      networking = {
        nftables.enable = true;
        # TODO fix, networkd is broken for some reason
        #useNetworkd = true;
      };
      x-banananetwork.privacy = {
        enable = true;
        ipv6IncreasedPrivacy = true;
      };
    }

    # hardware
    self.outputs.nixosProfiles.blade
    "${nixosHW}/common/cpu/intel/haswell"
    "${nixosHW}/common/pc/ssd"

    # host config
    {
      networking = {
        domain = "pc.6nw.de";
        hostName = "silverstone";
      };
    }
    self.outputs.modules.nixos.interactiveAppliance

    # state
    {
      system.stateVersion = "26.05";
      x-banananetwork.vmDisko = {
        generation = "ext4-1";
        mainDiskName = "main";
      };
      x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM7LKu14jQiBFwiFM1rfRdXYW3YG5qCtytmDoSA579D0 root@silverstone.pc.6nw.de 2026-10-31";
    }
  ];
  system = "x86_64-linux";
}
