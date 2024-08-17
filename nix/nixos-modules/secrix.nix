{ config
, lib
, pkgs
, ...
}:
let
  myOpts = config.x-banananetwork;
  cfg = config.x-banananetwork.secrix;
in
{


  options = {

    x-banananetwork.secrix = {

      enable = lib.mkEnableOption ''
        optioniated common secrix options.
      '';

      hostKeyType = lib.mkOption {
        description = ''
          Type of SSH host key to use.

          option{secrix.hostIdentityKey} will then automatically be set
          to the path set in option{services.openssh.hostKeys}
          for the host key with this type.

          Type names are the same used by
          e.g. option{services.openssh.hostKeys}
          or in OpenSSH `ssh-keygen -t` argument.

        '';
        type = with lib.types; nullOr str;
        default = null;
        example = lib.literalExpression "rsa";
      };

    };

  };


  config = lib.mkIf cfg.enable {


    assertions = [
      {
        assertion = config.secrix.hostPubKey != null;
        message = "secrix.hostPubKey must be defined";
      }
    ];


    secrix =
      let
        findHostKey = keyType: lib.lists.findSingle
          (key: key.type == keyType)
          (abort "cannot find generated OpenSSH host key with type ${keyType}")
          (abort "found multiple generated OpenSSH host keys with type ${keyType}")
          config.services.openssh.hostKeys;
        hostKeyPrivate = (findHostKey cfg.hostKeyType).path;
      in
      {

        defaultEncryptKeys."${myOpts.userName}" = myOpts.sshPublicKeys;

        hostIdentityFile = lib.mkIf (cfg.hostKeyType != null) (lib.mkDefault hostKeyPrivate);

      };


  };


}
