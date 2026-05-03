# auto-update build/test/suggest mechanism for NixOS systems
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins)
    concatLists
    readFile
    ;
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;

  # module "config"
  userHome = "/var/lib/srv-autoPush";
  userName = "srv-autoPush";

  # ===SYNC:general/meta/repo/url===
  repositoryRemote = "git@github.com:Zocker1999NET/server";
  repositoryLocal = "${userHome}/server";
  gcrootsDir = "${userHome}/gcroots";
  gpgKey = config.x-banananetwork.gpgSignatureKey;

  serviceScript = pkgs.writeShellApplication {
    name = userName;
    runtimeInputs = with pkgs; [
      config.nix.package
      bash
      findutils
      git
      gnupg
      openssh # required manually because of defining GIT_SSH_COMMAND
    ];
    text = readFile ./service.sh;
  };
in
{

  _class = "nixos";

  home-manager = {
    users.${userName} = {
      programs.gpg = {
        enable = true;
        mutableKeys = false;
        mutableTrust = false;
        publicKeys = singleton {
          source = gpgKey.path;
          trust = 5;
        };
      };
    };
  };

  nix.settings.allowed-users = singleton userName;

  systemd.services.${userName} = {
    environment = {
      CFG_repositoryRemote = repositoryRemote;
      CFG_repositoryLocal = repositoryLocal;
      CFG_gcrootsDir = gcrootsDir;
      CFG_gpgSignFingerprint = gpgKey.fingerprint;
      CFG_devKeyPath = config.secrix.services.${userName}.secrets.devKey.decrypted.path;
    };
    serviceConfig = {
      ExecStart = "${getExe serviceScript}";
      Group = userName;
      User = userName;
    };
    startAt = "*-*-* 23:00"; # documented in nixosModules/serverCommon.nix
  };
  secrix.services.${userName}.secrets.devKey.encrypted.file = ./devKey.age;

  users = {
    groups.${userName} = { };
    users.${userName} = {
      createHome = true;
      # description used by git as author
      description = "${userName}@${config.networking.fqdnOrHostName}";
      group = userName;
      home = userHome;
      isSystemUser = true;
      openssh.authorizedKeys.keys = concatLists [
        config.x-banananetwork.sshPublicKeys
      ];
      packages = with pkgs; [
        git
        gnupg
      ];
      useDefaultShell = true;
    };
  };

}
