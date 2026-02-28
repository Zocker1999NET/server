# options used across of my modules

# for me, most of them are defined in ../mySettings.nix

{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.options) mkOption;
in
{

  options = {

    x-banananetwork = {

      sshHostPublicKey = mkOption {
        description = ''
          SSH host public key of that system.

          This is used by other option{x-banananetwork} modules.
        '';
        type = with types; nullOr str;
        default = null;
        example = "ssh-ed25519 …";
      };

      sshPublicKeys = mkOption {
        description = ''
          SSH public keys used to manage this system.

          This is used by other option{x-banananetwork} modules.
        '';
        type = with types; listOf str;
        example = [ "ssh-ed25519 ..." ];
      };

      userName = mkOption {
        description = ''
          my username for most/all uses
        '';
        type = types.str;
        example = "zocker";
      };

    };

  };

}
