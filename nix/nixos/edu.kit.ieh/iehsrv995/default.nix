{
  outputs,
  ...
}@flakeArg:
{
  modules = [

    # TODO move into own modules
    (
      { config, ... }:
      {
        services.btrfs.autoScrub = {
          enable = true;
          interval = "weekly";
        };
        nix.sshServe = {
          enable = true;
          keys = config.x-banananetwork.sshPublicKeys;
          protocol = "ssh";
          write = true;
        };
        nix.settings.trusted-users = [ "nix-ssh" ];
        # allow connection for remote building
        users.users.iehadmin.openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKko0tcHOmCxi/ilFbVJ9N+U+34B9r6RFdmGfrBaob6C root@x13yz.pc.6nw.de"
        ];
      }
    )

    # host config
    {
      networking.domain = "ieh.kit.edu";
      networking.hostName = "iehsrv995";
      x-banananetwork.useable.enable = true;
      x-banananetwork.userName = "iehadmin";
      x-banananetwork.vmCommon.enable = true;
    }

    # hardware
    outputs.nixosProfiles.pveGuest

    # installation state
    (
      let
        btrfsRootOpts = [ "compress=zstd" ];
      in
      {
        fileSystems."/" = {
          device = "/dev/disk/by-uuid/cc109c2d-c70a-481d-9f1a-4c5c2e9cc964";
          fsType = "btrfs";
          options = [ "subvol=root" ] ++ btrfsRootOpts;
        };
        fileSystems."/home" = {
          device = "/dev/disk/by-uuid/cc109c2d-c70a-481d-9f1a-4c5c2e9cc964";
          fsType = "btrfs";
          options = [ "subvol=home" ] ++ btrfsRootOpts;
        };
        fileSystems."/nix" = {
          device = "/dev/disk/by-uuid/cc109c2d-c70a-481d-9f1a-4c5c2e9cc964";
          fsType = "btrfs";
          options = [ "subvol=nix" ] ++ btrfsRootOpts;
        };
        fileSystems."/boot" = {
          device = "/dev/disk/by-uuid/C551-A77E";
          fsType = "vfat";
          options = [
            "fmask=0077"
            "dmask=0077"
          ];
        };
        swapDevices = [ { device = "/dev/disk/by-uuid/42ac2839-0bb1-45ac-ad00-6b49142bf965"; } ];
      }
    )
    {
      system.stateVersion = "24.05";
      x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJlrzgVqPcIUbkMHVOQZgee9j2CwfDiW4oJhUKdIcQKV iehsrv995";
    }

  ];
  system = "x86_64-linux";
}
