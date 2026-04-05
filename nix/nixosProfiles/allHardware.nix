# all hardware for *installed* systems

{ modulesPath, ... }:
{

  _class = "nixos";

  imports = [
    # from nixpkgs
    "${modulesPath}/profiles/all-hardware.nix" # all hardware, just so installers from USB / etc. can run
    # from here
    ./common.nix
    ./pveGuestHwSupport.nix # also for guest agent, serial out, ...
  ];

  config = {
    boot.initrd.availableKernelModules = [
      # to find boot drive
      "mmc_block" # e.g. Surface 3
      "sdhci-acpi" # e.g. Surface 3
    ];
  };

}
