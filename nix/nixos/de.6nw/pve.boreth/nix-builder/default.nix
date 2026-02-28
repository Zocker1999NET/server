{ lib, outputs, ... }@flakeArg:
let
  inherit (builtins) concatLists;
  inherit (lib.lists) singleton;
in
{
  modules = [

    ./srv-autoPush
    ./srv-autoUpdate

    # publish nix store via http
    (
      { config, ... }:
      {
        services.nix-serve = {
          enable = true;
          bindAddress = ""; # enable for both IPv4 & IPv6
          port = 5000;
          openFirewall = true;
          secretKeyFile = config.secrix.services.nix-serve.secrets.secretKeyFile.decrypted.path;
        };
        # nix-store --generate-binary-cache-key nix-builder.boreth.pve.6nw.de-1 ./secret ./public
        secrix.services.nix-serve.secrets.secretKeyFile.encrypted.file = ./secretKeyFile;
      }
    )

    (
      { config, ... }:
      {
        nix.sshServe = {
          # provides remote builder with user nix-ssh
          enable = true;
          keys = concatLists [
            config.x-banananetwork.sshPublicKeys
            # allow connection for remote building
            [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKko0tcHOmCxi/ilFbVJ9N+U+34B9r6RFdmGfrBaob6C root@x13yz.pc.6nw.de"
            ]
          ];
          protocol = "ssh-ng";
          trusted = true;
          write = true;
        };

        # re-configure gc for longer preservation
        nix = {
          settings = {
            max-free = 10 * 1024 * 1024 * 1024;
            min-free = 5 * 1014 * 1024 * 1024;
          };
        };
      }
    )

    # config
    (
      { config, pkgs, ... }:
      {
        networking = {
          hostName = "nix-builder";
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
      system.stateVersion = "25.05";
      x-banananetwork.vmDisko = {
        generation = "ext4-1";
        mainDiskName = "main";
      };
      x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFVPIdZSEEc279bar6k8FEwH71IdeNKkN2YE1/yojz4i root@nix-builder.boreth.pve.6nw.de 2025-07-19";
    }

  ];
  system = "x86_64-linux";
}
