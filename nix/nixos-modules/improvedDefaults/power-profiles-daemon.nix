{ config, lib, ... }:
let
  cfg = config.x-banananetwork.improvedDefaults;
  tlpEn = config.services.tlp.enable;
in
{
  # power-profiles-daemon gets enabled by most display managers
  # so this suppresses this if another daemon is enabled
  config = lib.mkIf cfg.enable { services.power-profiles-daemon.enable = lib.mkIf tlpEn false; };
}
