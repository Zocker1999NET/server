{ lib, outputs, ... }@flakeArg:
let
  inherit (lib.lists) singleton;
in
{
  modules = [

    # DB parts
    (
      { config, pkgs, ... }:
      {
        networking.firewall = {
          allowedTCPPorts = [
            3389
          ];
        };
        services.mysql = {
          enable = true;
          ensureDatabases = singleton "ethnodes";
          ensureUsers = [
            {
              name = "zocker";
              ensurePermissions."*.*" = "ALL PRIVILEGES";
            }
          ];
          package = pkgs.mariadb;
        };
        virtualisation.containers.enable = true;
        virtualisation = {
          oci-containers = {
            backend = "podman";
            containers = {
              phpmyadmin = {
                environment = {
                  "PMA_HOST" = "host.containers.internal";
                };
                image = "docker.io/library/phpmyadmin:latest";
                ports = [
                  "80:80"
                ];
              };
            };
          };
          podman = {
            enable = true;
            # Create a `docker` alias for podman, to use it as a drop-in replacement
            dockerCompat = true;
            # Required for containers under podman-compose to be able to talk to each other.
            defaultNetwork.settings.dns_enabled = true;
          };
        };
      }
    )

    # config
    (
      { config, pkgs, ... }:
      {
        networking = {
          hostName = "rfc-ss2025";
          domain = "boreth.pve.6nw.de";
        };
        x-banananetwork = {
          useable.enable = true;
          vmCommon.enable = true;
        };
      }
    )

    # hardware
    outputs.nixosProfiles.pveGuest

    # installation state
    {
      system.stateVersion = "24.11";
      x-banananetwork.vmDisko = {
        generation = "ext4-1";
        mainDiskName = "main";
      };
    }

  ];
  system = "x86_64-linux";
}
