{
  outputs,
  ...
}@flakeArg:
{
  modules = [

    # host config
    {
      networking.domain = "ieh.kit.edu";
      networking.hostName = "iehsrv994";
      x-banananetwork.useable.enable = true;
      x-banananetwork.userName = "iehadmin";
      x-banananetwork.vmCommon.enable = true;
    }

    # hardware
    outputs.nixosProfiles.pveGuest

    # installation state
    {
      system.stateVersion = "25.11";
      x-banananetwork.vmDisko = {
        generation = "ext4-1";
        mainDiskName = "main";
      };
    }

  ];
  system = "x86_64-linux";
}
