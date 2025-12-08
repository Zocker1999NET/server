{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  inherit (lib.meta) getExe';
  inherit (lib.options) mkOption;
  inherit (lib.strings) concatMapStrings;
  inherit (lib.trivial) flip;

  blocked = config.boot.blockedKernelModules;
in
{

  options = {
    boot.blockedKernelModules = mkOption {
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
      apply = mods: lib.attrNames (lib.filterAttrs (_: v: v) mods);
      default = { };
    };
  };

  config = {
    boot.blacklistedKernelModules = blocked;
    boot.extraModprobeConfig = flip concatMapStrings blocked (module: ''
      install ${module} ${getExe' pkgs.coreutils "true"}
    '');
  };

}
