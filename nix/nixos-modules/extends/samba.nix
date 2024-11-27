{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) attrValues concatStringsSep filter;
  inherit (lib) types;
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  esc = lib.strings.escapeShellArg;
  inherit (lib.trivial) pipe;
  # module values
  servName = "samba-user-config";
  smbUsers = pipe config.users.users [
    attrValues
    (map (u: { inherit (u) name; } // u.samba))
    (filter (u: u.passwordFile != null))
  ];
in
# TODO upstream
{

  options.users.users = mkOption {
    type = types.attrsOf (
      types.submodule (
        { ... }:
        {

          options.samba = {
            passwordFile = mkOption {
              description = ''
                Configures the Samba password for this local user.

                Because of Samba’s implementation, the password must be supplied in plaintext.
                For safety reasons, the password must be supplied using a file
                to avoid it being saved in the Nix store.

                To allow easier integration with some secret managing schemes,
                the user passwords are populated by `${servName}.service` running as root,
                therefore requiring read access to the password file.

                If set to `none`, the Samba password will not be modified.
              '';
              type = with types; nullOr str;
              default = null;
              example = "/etc/secrets/smb_pass_file";
            };
          };

        }
      )
    );
  };

  config = mkIf (config.services.samba.enable && smbUsers != [ ]) {
    # as service for usability with secret managing schemes (like secrix)
    systemd.services.${servName} = {
      # TODO original
      description = "Apply NixOS user configuration to Samba";
      before = singleton "samba-smbd.service";
      partOf = singleton "samba-smbd.service";
      wantedBy = singleton "samba-smbd.service";
      restartIfChanged = true;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = pipe smbUsers [
        (map (u: ''
          # user: ${u.name}
          if [[ -f ${esc u.passwordFile} ]]; then
            ${pkgs.coreutils}/bin/cat ${esc u.passwordFile} ${esc u.passwordFile} | ${config.services.samba.package}/bin/smbpasswd -a -s ${esc u.name}
          else
            echo "Cannot set Samba password for "${esc u.name}", samba.passwordFile not found: "${esc u.passwordFile} >&2
            exit 2
          fi
        ''))
        (concatStringsSep "\n")
      ];
    };
  };

}
