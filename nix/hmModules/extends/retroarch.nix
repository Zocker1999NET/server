{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.retroarch;
  inherit (lib) types;
  inherit (lib.lists) singleton;
  inherit (lib.options)
    literalExpression
    mkEnableOption
    mkOption
    mkPackageOption
    ;
in
{
  options.programs.retroarch = {

    enable = mkEnableOption "RetroArch as user program";

    package = mkPackageOption pkgs "retroarch" {
      example = literalExpression "pkgs.retroarchFull";
    };

    cores = mkOption {
      description = "List of cores to install.";
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "with pkgs.libretro; [ twenty-fortyeight ]";
    };

    finalPackage = mkOption {
      description = "RetroArch package with the cores selected";
      type = types.package;
      readOnly = true;
      default =
        # providing the _coresBuiltin for selection via option is non-trivial
        # but this should also be supported for now
        if cfg.cores == [ ] then cfg.package else cfg.package.withCores (_coresBuiltin: cfg.cores);
      defaultText = ''
        with config.programs.retroarch;
        package.withCores (_: cores)
      '';
    };

  };
  config = {

    home.packages = singleton cfg.finalPackage;

  };
}
