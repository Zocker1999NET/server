# options used across of my modules

# for me, most of them are defined in ../mySettings.nix

{ config
, lib
, pkgs
, ...
}:
{

  options = {

    x-banananetwork = {

      sshHostPublicKey = lib.mkOption {
        description = ''
          SSH host public key of that system.

          This is used by other option{x-banananetwork} modules.
        '';
        type = with lib.types; nullOr str;
        example = lib.literalExpression ''
          ssh-ed25519 …
        '';
      };

      sshPublicKeys = lib.mkOption {
        description = ''
          SSH public keys used to manage this system.

          This is used by other option{x-banananetwork} modules.
        '';
        type = with lib.types; listOf str;
        example = lib.literalExpression ''
          [ "ssh-ed25519 ..." ]
        '';
      };

      userName = lib.mkOption {
        description = ''
          my username for most/all uses
        '';
        type = lib.types.str;
        example = lib.literalExpression "zocker";
      };

    };

  };

}
