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
  inherit (lib.strings) isStorePath;

  gpgKey = types.submodule (
    { config, name, ... }:
    {
      options = {
        fingerprint = mkOption {
          description = "fingerprint of the GPG key";
          type = types.strMatching "^[A-F0-9]+$";
          example = "73D09948B2392D688A45DC8393E1BD26F6B02FB7";
        };
        path = mkOption {
          description = "path of the file with the public key";
          type = types.path;
          example = "/location/of/public/key.gpg";
        };
        output = mkOption {
          description = ''
            The recommended output to use.
            If required, does decouple the single file from the whole flake,
            preventing the whole flake from becoming a dependency of the (built) system.
          '';
          type = types.path;
          internal = true;
          readOnly = true;
          default =
            if isStorePath config.path then
              pkgs.concatText "${config.fingerprint}.gpg" [ config.path ]
            else
              config.path;
        };
      };
    }
  );
in
{

  _class = "nixos";

  options = {

    x-banananetwork = {

      localTimeZone = mkOption {
        description = ''
          The local time zone for this system.

          Used where a local time zone is expected (e.g., external interactions),
          though configs generally prefer UTC.
        '';
        type = types.str;
        example = "Europe/Berlin";
      };

      gpgSignatureKey = mkOption {
        description = ''
          The GPG key used to sign the commits on my Nix config repo & most other Git repos.
        '';
        type = gpgKey;
      };

      gpgTrustedKeys = mkOption {
        description = ''
          All of my fully trusted GPG keys. (i.e. trust=5)
        '';
        type = types.listOf gpgKey;
      };

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
