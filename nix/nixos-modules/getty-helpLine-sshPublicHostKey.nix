{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.getty.dynamicHelpLine.${name};
  sshCfg = config.services.openssh;
  name = "sshPublicHostKey";
  description = ''posting SSH host public key onto getty login screen'';
  generator = pkgs.writeShellApplication {
    name = "${name}-generator";
    text = ''
      for f in /etc/ssh/ssh_host_*_key.pub; do
        ${config.services.openssh.package}/bin/ssh-keygen -lf "$f"
      done
      echo  # extra new line at end of file as spacer
    '';
  };
  enableReason = cfg.enable && sshCfg.enable;
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
  generatorExe = getExe generator;
in
{

  options.services.getty.dynamicHelpLine.${name} = {
    enable = mkEnableOption description;
  };

  config.systemd.services = mkIf enableReason {
    "getty-helpLine-${name}" = {
      inherit description;
      # dependencies
      after = singleton "sshd.service";
      wantedBy = singleton "getty@.service";
      # service config
      restartIfChanged = true;
      serviceConfig = {
        Type = "oneshot";
      };
      # script
      enableStrictShellChecks = true;
      script = ''
        # prepare out file
        mkdir --parents /etc/issue.d
        out_file="/etc/issue.d/${name}.issue"
        # prepare generator execution
        echo "+ ${generatorExe}" >&2
        # tee output to logs, in case it contains error message
        if ${generatorExe} | tee "$out_file"; then
          exit 0;
        else
          exit_code="$?"
          echo "${generatorExe} exited with $exit_code" >&2
          # overwrite output file with error statement
          echo "[dynamicHelpLine ${name} failed, see logs in journal]" > "$out_file"
          # repeat exit code to systemd
          exit "$exit_code"
        fi
      '';
    };
  };

}
