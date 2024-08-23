{ config, lib, ... }:
let
  cfg = config.x-banananetwork.improvedDefaults;
  nmEn = config.networking.networkmanager.enable;
  waitOnlineEn = config.systemd.network.wait-online.enable;
in
{

  config = lib.mkIf cfg.enable {
    systemd.network.wait-online.enable = lib.mkIf nmEn (lib.mkDefault false);

    warnings = lib.singleton (
      lib.mkIf (nmEn && waitOnlineEn) ''
        systemd-networkd-wait-online is in most cases useless on systems primarily using NetworkManager & it may increase boot times if it just fails
      ''
    );
  };

}
