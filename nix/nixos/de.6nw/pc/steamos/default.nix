{
  inputs,
  lib,
  outputs,
  ...
}:
{
  modules = [

    # system config
    {
      jovian.steam = {
        enable = true;
        autoStart = true;
        desktopSession = "gamescope-wayland"; # i.e. no desktop mode
        updater.splash = "bgrt";
      };
      networking.networkmanager.enable = true;
    }
    "${inputs.jovian-nixos}/modules"

    # user config
    (
      { config, ... }:
      let
        cfg = config.x-banananetwork.serverCommon; # temporary lookup there
      in
      {
        jovian.steam.user = cfg.userName;
        users = {
          mutableUsers = false;
          users.${cfg.userName} = {
            uid = 1000;
            description = cfg.userName;
            extraGroups = [
              (lib.mkIf config.networking.networkmanager.enable "networkmanager")
            ];
            inherit (cfg) hashedPassword;
            isNormalUser = true;
            openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
          };
          users.root.openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
        };
      }
    )

    # unfree packages
    (
      { config, ... }:
      {
        x-banananetwork.autoUnfree = {
          enable = true;
          names = lib.optional config.jovian.steam.enable "steamdeck-hw-theme";
        };
      }
    )

    # host config
    {
      networking.domain = "pc.6nw.de";
      networking.hostName = "steamos";
    }

    # configure jovian hardware
    (
      { config, ... }:
      {
        jovian.hardware.has.amd.gpu = config.hardware.graphics.amd.enable;
      }
    )

    # hardware
    outputs.nixosProfiles.blade
    {
      hardware = {
        cpu.type = "amd";
        graphics.amd.enable = true;
      };
    }

    # state
    {
      system.stateVersion = "24.11";
      x-banananetwork.vmDisko = {
        generation = "ext4-1";
        mainDiskName = "main";
      };
    }

  ];
  system = "x86_64-linux";
}
