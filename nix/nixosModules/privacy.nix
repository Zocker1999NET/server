{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.x-banananetwork.privacy;
in
{

  _class = "nixos";

  options = {

    x-banananetwork.privacy = {

      enable = lib.mkEnableOption ''
        system settings which attempt to increase privacy.
      '';

      # TODO implement
      ipv6IncreasedPrivacy = lib.mkEnableOption ''
        increased IPv6 privacy meassures.

        Decreases the time IPv6 privacy extension addresses are used.
      '';

    };

  };

  config = lib.mkIf cfg.enable {

    boot.kernel.sysctl = {
      "net.ipv6.conf.all.temp_prefered_lft" = 1 * 60 * 60; # = 1h
      "net.ipv6.conf.all.temp_valid_lft" = 21 * 60 * 60; # = 21h
    };

    networking = {
      tempAddresses = "default";
    };

  };

}
