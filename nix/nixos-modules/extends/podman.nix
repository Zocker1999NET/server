{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.podman;
in
{
  options.virtualisation.podman = {
    compose.enable = lib.mkEnableOption "podman-compose";
  };
  config.environment.systemPackages = lib.mkIf (cfg.enable && cfg.compose.enable) [
    pkgs.podman-compose
  ];
}
