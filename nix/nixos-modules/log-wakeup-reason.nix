{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.log-wakeup-reason;
  inherit (lib) types;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption mkOption;
in
{

  options.services.log-wakeup-reason = {
    enable = mkEnableOption "logging wake-up reason into journal";
    onTargets = mkOption {
      description = ''
        systemd Targets on which to log wake-up reason (after waking up from them).
      '';
      type = with types; listOf str;
      default = [
        "suspend.target"
        "hibernate.target"
        "hybrid-sleep.target"
        "suspend-then-hibernate.target"
      ];
    };
  };

  config = mkIf cfg.enable {
    systemd.services.log-wakeup-reason = {
      after = cfg.onTargets;
      wantedBy = cfg.onTargets;
      script = ''
        ${getExe pkgs.dmidecode} | ${getExe pkgs.gnugrep} Wake-up
      '';
    };
  };

}
