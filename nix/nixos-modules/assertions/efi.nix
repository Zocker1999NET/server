{
  config,
  lib,
  options,
  ...
}:
let
  inherit (lib.strings) escapeNixString;
  cfg = config.boot.loader;
  fs = config.fileSystems;
  efiIndicator = builtins.any (x: x) [
    (cfg.grub.enable && cfg.grub.efiSupport)
    (cfg.systemd-boot.enable)
  ];
  efiMountPath = escapeNixString cfg.efi.efiSysMountPoint;
  efiMount = fs.${cfg.efi.efiSysMountPoint} or null;
in
# TODO check cfg.grub.mirroredBoots as well
# TODO enable disko checks (optional i.e. when disko options are available)
{
  config = lib.mkIf efiIndicator {

    assertions = [
      {
        assertion = efiMount != null;
        message = ''
          There is no filesystem declaration for EFI System Partition ${efiMountPath}
        '';
      }
      {
        assertion = efiMount != null -> efiMount.fsType == "vfat";
        message = ''
          EFI System Partition ${efiMountPath} has not fsType "vfat"
        '';
      }
    ];

  };
}
