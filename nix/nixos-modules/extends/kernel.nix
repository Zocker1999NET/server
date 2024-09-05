{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  blocked = config.boot.blockedKernelModules;
in
{

  options = {
    boot.blockedKernelModules = lib.mkOption {
      description = ''
        Kernel modules which are blocked from being loaded
        by using a rather hacky workaround called "fake install".
        Read in the [Debian Wiki](https://wiki.debian.org/KernelModuleBlacklisting) for more info.

        Be aware that this should block all attempts
        from loading that module at runtime,
        *including other modules* depending on it.

        Modules listed here are automatically blacklisted as well
        by adding them to {option}`boot.blacklistedKernelModules`,
        which should hinder them being loaded automatically
        due to supported devices detected.
      '';
      type = options.boot.blacklistedKernelModules.type;
      default = [ ];
    };
  };

  config = {
    boot.blacklistedKernelModules = blocked;
    boot.extraModprobeConfig = lib.flip lib.concatMapStrings blocked (module: ''
      install ${module} ${lib.getExe' pkgs.coreutils "true"}
    '');
  };

}
