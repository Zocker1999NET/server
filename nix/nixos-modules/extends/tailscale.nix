{ config, lib, ... }:
let
  cfg = config.services.tailscale;
  toTsCli = lib.cli.toGNUCommandLine {
    mkBool = k: v: lib.singleton "--${k}=${lib.boolToString v}";
    mkList = k: v: lib.singleton "--${k}=${builtins.concatStringsSep "," v}";
    mkOption =
      k: v:
      if v == null then [ ] else lib.singleton "--${k}=${lib.generators.mkValueStringDefault { } v}";
  };
in
{

  options.services.tailscale = {

    setFlags = lib.mkOption {
      description = ''
        Options which are given to `tailscale set` on every boot.
        Will be translated to {option}`services.tailscale.extraSetFlags`.
      '';
      type = lib.types.anything;
      default = { };
      example = {
        advertise-exit-node = true;
        advertise-tags = [
          "mytag"
          "other"
        ];
        netfilter-mode = "none";
      };
    };

    upFlags = lib.mkOption {
      description = ''
        Will be translated to {option}`services.tailscale.extraUpFlags`.
      '';
      type = lib.types.anything;
      default = { };
      example = {
        ssh = true;
        advertise-tags = [
          "mytag"
          "other"
        ];
      };
    };

  };

  config = lib.mkIf cfg.enable {

    services.tailscale = {
      extraSetFlags = toTsCli cfg.setFlags;
      # apply set flags already on autoconnect
      extraUpFlags = toTsCli cfg.upFlags ++ cfg.extraSetFlags;
    };

    # ensure tailscale set settings really apply
    systemd.services.tailscaled-set = lib.mkIf (cfg.authKeyFile != null) {
      after = lib.singleton "tailscaled-autoconnect.service";
      wants = lib.singleton "tailscaled-autoconnect.service";
    };

  };

}
