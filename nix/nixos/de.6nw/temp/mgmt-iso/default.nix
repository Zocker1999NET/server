{
  flake,
  lib,
  outputs,
  ...
}@flakeArg:
{
  # TODO integrate into auto-iso, see taskwarrior:///321e5090-fe7d-4fc8-aeee-0117a344f33a
  modules = [

    # host config
    (
      { config, pkgs, ... }:
      {
        config = {
          documentation.info.enable = lib.mkForce false;
          environment.systemPackages = with pkgs; [
            nwipe # make wiping disks easier
          ];
          isoImage.edition = "de.6nw-mgmt";
          networking.hostName = "mgmt-iso";
          programs.disko-install-menu = {
            enable = true;
            listedFlakes.defaultFlake = {
              offlineHosts = {
                "empty" = true;
              };
              offlineReference = flake;
            };
            offlineCapable = true;
            options = {
              # TODO autostart
              defaultFlake = "github:Zocker1999NET/server"; # ===SYNC:general/meta/repo/url
              defaultHost = "empty";
            };
          };
          users.users.root.openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
          x-banananetwork = {
            useable.enable = true;
          };
        };
      }
    )
    ./../../../../offlineInstallDeps.nix

    # hardware & "state"
    outputs.nixosProfiles.installer

  ];
  system = "x86_64-linux";
}
