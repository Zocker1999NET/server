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

      sshPublicKeys = lib.mkOption {
        description = ''
          SSH public keys used to manage this system.

          This is used by other option{x-banananetwork} modules.
        '';
        example = lib.literalExpression ''
          [ "ssh-ed25519 ..." ]
        '';
      };

      userName = lib.mkOption {
        description = ''
          my username for most/all uses
        '';
        example = lib.literalExpression "zocker";
      };

    };

  };

}
