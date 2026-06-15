{ lib, self, ... }@flakeArg:
let
  inherit (lib.lists) singleton;
in
{
  modules = [

    # config
    (
      { config, pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          #
        ];
        networking = {
          hostName = "dns";
          domain = "boreth.pve.6nw.de";
          firewall = {
            allowedTCPPorts = singleton 53;
            allowedUDPPorts = singleton 53;
          };
        };
        services.bind = {
          enable = true;
          # TODO disabled because including runtime files fails check at buildtime
          checkConfig = false;
          # TODO extract secrets (we can include external files)
          extraConfig =
            let
              secret = name: ''"${config.secrix.services."bind".secrets.${name}.decrypted.path}"'';
            in
            ''
              include ${secret "tsig_router.boreth.pve.6nw.de."};
            '';
          zonesExt = {
            "6nw.de." = {
              dynamic = true;
              update-policy = [
                ''grant "local-ddns" zonesub any''
                ''grant "router.boreth.pve.6nw.de." wildcard *.boreth.pve.6nw.de. any''
              ];
              initialContent = ''
                $ORIGIN 6nw.de.
                $TTL 3600
                @ IN SOA ns1.banananet.work. hostmaster.banananet.work. 1000 24h 2h 6w 1h
                @ IN NS ns1.banananet.work.
              '';
            };
          };
        };
        secrix.services."bind".secrets = {
          # tsig-keygen -a hmac-sha512 router.boreth.pve.6nw.de. | secr encrypt dns.boreth.pve.6nw.de --system router.boreth.pve.6nw.de
          "tsig_router.boreth.pve.6nw.de.".encrypted.file = ./tsig_router.boreth.pve.6nw.de.age;
        };
        x-banananetwork = {
          vmCommon.enable = true;
        };
      }
    )

    # hardware
    self.outputs.nixosProfiles.pveGuest

    # installation state
    {
      system.stateVersion = "24.05";
      x-banananetwork.vmDisko = {
        generation = "ext4-1";
        mainDiskName = "main";
      };
      x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAdq1IbVu7uaClh3nrewepnqx2vtZyxg6bVKypo6pMgk root@dns.boreth.pve.6nw.de 2024-11-01";
    }

  ];
  system = "x86_64-linux";
}
