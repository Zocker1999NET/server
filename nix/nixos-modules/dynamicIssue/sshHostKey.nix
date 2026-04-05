{
  config,
  lib,
  ...
}:
let
  modEn = config.services.dynamicIssue.modules.sshHostKey.enable;
  sshCfg = config.services.openssh;

  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf;
in
{
  _class = "nixos";
  config = {
    services.dynamicIssue.implementations.sshHostKey = {
      description = "hashes of SSH host public keys";
      after = singleton "sshd.service";
      script = ''
        for f in /etc/ssh/ssh_host_*_key.pub; do
          ${sshCfg.package}/bin/ssh-keygen -lf "$f"
        done
        echo  # extra new line at end of file as spacer
      '';
    };
    warnings = singleton (
      mkIf (modEn && !sshCfg.enable)
        "services.dynamicIssue.modules.sshHostKey probably cannot find any SSH host public keys when services.openssh is disabled"
    );
  };
}
