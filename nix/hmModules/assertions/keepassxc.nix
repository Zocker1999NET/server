{
  config,
  lib,
  osConfig ? null,
  pkgs,
  ...
}:
let
  inherit (builtins) elem;
  inherit (lib.modules) mkIf;
  inherit (lib.trivial) defaultTo;

  cfg = config.programs.keepassxc;
  package = defaultTo pkgs.keepassxc cfg.package;

  isHomeInstalled = elem package config.home.packages;
  isSystemInstalled = elem package osConfig.environment.systemPackages;
in
{
  _class = "homeManager";
  config = mkIf (!isNull osConfig) {

    warnings = [
      # quick unlock requires an action policy from KeePassXC package to be installed system-wide
      (mkIf ((cfg.enable || isHomeInstalled) && !isSystemInstalled) ''
        KeePassXC installed via Home-Manager but not via NixOS environment.systemPackages (or not used same package), may cause issues with D-Bus integration & quick unlock
      '')
    ];

  };
}
