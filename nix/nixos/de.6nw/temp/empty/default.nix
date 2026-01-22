{
  inputs,
  outputs,
  ...
}@flakeArg:
{
  # temporary, transistevy system
  modules = [

    # TODO split vmCommon & use here
    (
      { config, lib, ... }:
      {
        disko.devices.disk.main.device = lib.mkForce "/dev/sda";
        # EFI only
        boot.loader = {
          efi.canTouchEfiVariables = true;
          grub.enable = false;
          grub.efiSupport = true;
          systemd-boot.enable = true;
        };
        services = {
          dynamicIssue.modules = {
            sshHostKey.enable = true;
          };
          getty.helpLine = "IPs:  \\4  \\6";
          openssh.enable = true;
        };
        x-banananetwork = {
          allCommon.enable = true;
          useable.enable = true;
        };
        users = {
          mutableUsers = false; # TODO move that (maybe to common?)
          users.${config.x-banananetwork.userName} = {
            description = config.x-banananetwork.userName;
            extraGroups = [ "wheel" ];
            hashedPassword = "$y$j9T$MdvgnTFGyCnZ.sLhXK7.w.$VkI6NqE7ZaN7xULmOrYCvgC6Sot19S0RWf.FmrOaLnC";
            isNormalUser = true;
            openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
          };
          users.root.openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
        };
      }
    )
    (
      { config, lib, ... }:
      {
        networking.hostName = "empty";
        networking.domain = "temp.6nw.de";
        secrix.hostPubKey = lib.mkForce null;
      }
    )

    # hardware
    outputs.nixosProfiles.allHardware

    # "installation" state
    (
      { config, lib, ... }:
      {
        system.stateVersion = lib.versions.majorMinor config.system.nixos.version;
        x-banananetwork.vmDisko = {
          generation = config.x-banananetwork.vmDisko.recommendedGeneration;
          mainDiskName = "main";
        };
      }
    )

  ];
  system = "x86_64-linux";
}
