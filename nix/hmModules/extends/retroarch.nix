{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.retroarch;
in
{
  options.programs.retroarch = {

    enable = lib.mkEnableOption "RetroArch as user program";

    package = lib.mkPackageOption pkgs "retroarch" {
      example = lib.literalExpression "pkgs.retroarchFull";
    };

    cores = lib.mkOption {
      description = "List of cores to install.";
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "with pkgs.libretro; [ twenty-fortyeight ]";
    };

    finalPackage = lib.mkOption {
      description = "RetroArch package with the cores selected";
      type = lib.types.package;
      readOnly = true;
      default = if cfg.cores == [ ] then cfg.package else cfg.package.override { inherit (cfg) cores; };
      defaultText = ''
        with config.programs.retroarch;
        package.override { inherit cores; }
      '';
    };

  };
  config = {

    home.packages = lib.singleton cfg.finalPackage;

  };
}
