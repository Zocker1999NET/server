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
  inherit (lib.meta) getExe;

  # module "config"
  userHome = "/var/lib/srv-autoUpdate";
  userName = "srv-autoUpdate";

  # ===SYNC:general/meta/repo/url===
  repositoryRemote = "https://github.com/Zocker1999NET/server";
  repositoryLocal = "${userHome}/server";

  serviceScript = pkgs.writeShellApplication {
    name = userName;
    runtimeInputs = with pkgs; [
      config.nix.package
      bash
      git
    ];
    text = readFile ./service.sh;
  };
in
{

  systemd.services.${userName} = {
    environment = {
      CFG_repositoryRemote = repositoryRemote;
      CFG_repositoryLocal = repositoryLocal;
    };
    serviceConfig = {
      ExecStart = "${getExe serviceScript}";
      Group = userName;
      User = userName;
    };
    startAt = "Sam *-*-* 08:00"; # documented in nixos-modules/serverCommon.nix
  };

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
      ];
      useDefaultShell = true;
    };
  };

}
