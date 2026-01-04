{
  outputs,
  ...
}@flakeArg:
let
  inherit (builtins) concatStringsSep;
in
{
  modules = [

    # tailscale VPN config
    (
      { config, ... }:
      {
        services.tailscale = {
          enable = true;
          authKeyFile = config.secrix.services.tailscaled-autoconnect.secrets.authKey.decrypted.path;
          openFirewall = true;
          setFlags = {
            accept-dns = false;
            accept-routes = false;
            advertise-exit-node = true;
            advertise-routes = concatStringsSep "," [
              # KIT (https://www.scc.kit.edu/dienste/ip-subnets.php)
              "2a00:1398::/32"
              "2a00:139e::/32"
              "129.13.0.0/16"
              "141.3.0.0/16"
              "141.52.0.0/16"
              "185.237.152.0/22"
              "193.196.32.0/20"
              "172.16.0.0/12" # (privat / Intranet)
              "192.168.0.0/16" # (privat / Intranet)
            ];
            hostname = "prox-vm994";
          };
          upFlags = {
            advertise-tags = [
              "tag:iperf3"
              "tag:none"
              "tag:recursive-dns"
            ];
          };
          useRoutingFeatures = "both";
        };
        secrix.services.tailscaled-autoconnect.secrets.authKey.encrypted.file = ./tailscale-auth-key;
      }
    )

    # host config
    {
      networking.domain = "ieh.kit.edu";
      networking.hostName = "iehsrv994";
      x-banananetwork.useable.enable = true;
      x-banananetwork.userName = "iehadmin";
      x-banananetwork.vmCommon.enable = true;
    }

    # hardware
    outputs.nixosProfiles.pveGuest

    # installation state
    {
      system.stateVersion = "25.11";
      x-banananetwork.vmDisko = {
        generation = "ext4-1";
        mainDiskName = "main";
      };
      x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGrM4RZA35Q5iO3tI3dPNpYc3/kBkUqYqBj0nQPuBMtR root@iehsrv994.ieh.kit.edu 2026-01-04";
    }

  ];
  system = "x86_64-linux";
}
