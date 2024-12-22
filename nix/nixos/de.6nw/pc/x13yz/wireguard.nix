{ config, ... }:
{
  secrix.services."systemd-networkd".secrets.wg0-key.encrypted.file = ./wg0.key.age;
  systemd.network.enable = true;
  systemd.network.networks."wg0" = {
    name = "wg0";
    address = [ "10.111.111.1/24" ];
  };
  systemd.network.netdevs."wg0" = {
    netdevConfig = {
      Name = "wg0";
      Kind = "wireguard";
    };
    wireguardConfig = {
      ListenPort = 51820;
      PrivateKeyFile = config.secrix.services."systemd-networkd".secrets.wg0-key.decrypted.path;
    };
  };
}
