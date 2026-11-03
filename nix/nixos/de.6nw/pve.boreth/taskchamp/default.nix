{ self, ... }:
{
  modules = [

    {
      services.taskchampion-sync-server = {
        enable = true;
        # I do not want to reveal my client ID here
        # TODO allow all IDs until module supports --no-create-clients
        allowClientIds = [ ];
        host = ""; # on all interfaces
        openFirewall = true;
        port = 10222; # module default
      };
    }

    # config
    {
      networking = {
        hostName = "taskchamp";
        domain = "boreth.pve.6nw.de";
      };
      x-banananetwork = {
        useable.enable = true;
        vmCommon.enable = true;
      };
    }

    # hardware
    self.outputs.nixosProfiles.pveGuest

    # installation state
    {
      system.stateVersion = "26.05";
      x-banananetwork.vmDisko = {
        generation = "ext4-1";
        mainDiskName = "main";
      };
      x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGsz9qcDIWtMVa5uZp0HSukqtElWQL/DmzJElfL5Traw root@taskchamp.boreth.pve.6nw.de 2026-11-03";
    }

  ];
  system = "x86_64-linux";
}
