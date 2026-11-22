{ lib, self, ... }@flakeArg:
let
  inherit (builtins)
    attrNames
    attrValues
    concatLists
    concatStringsSep
    ;
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkForce;

  concatMapped =
    sep: xs: f:
    concatStringsSep sep (map f xs);

  # addresses from https://docs.hetzner.com/networking/dns/overview#authoritative-name-servers
  hetznerSecondaryServers = {
    "ns1.first-ns.de." = [
      "213.239.242.238"
      "2a01:4f8:0:a101::a:1"
    ];
    "robotns2.second-ns.de." = [
      "213.133.100.103"
      "2a01:4f8:0:1::5ddc:2"
    ];
    "robotns3.second-ns.com." = [
      "193.47.99.3"
      "2001:67c:192c::add:a3"
    ];
  };
  hetznerSecondaryServerIPs = concatLists (attrValues hetznerSecondaryServers);
in
{
  modules = [

    # dynamic primary nameserver reflector for Hetzner DNS
    (
      { config, ... }:
      let
        inherit (builtins) concatLists map typeOf;
        # tag a source with its IP version, plain URLs untouched otherwise
        srcOnly =
          class: url:
          if typeOf url == "set" then
            url // { inherit class; }
          else
            {
              inherit class url;
            };
        inherit (config.secrix.services."dns-dynamic-primary-reflector") secrets;
      in
      {
        # bind here is only authoritative, so not use it as system resolver
        networking.resolvconf.useLocalResolver = mkForce false;
        services.dns-dynamic-primary-reflector = {
          enable = true;
          settings = {
            hetzner_domains = [
              "allglorytojesus.de"
            ];
            ip_consensus_max_uniform = 3;
            ip_consensus_minimum = 2;
            ip_sources = [
              # layers are attempted one by one, until required numbers are fulfilled
              # sources in each layer are queried in a randomized order
              (concatLists [
                [
                  "https://icanhazip.com"
                  "https://ip.hetzner.com"
                ]
                (map (srcOnly "ipv4") [
                  "https://checkip.amazonaws.com/"
                  {
                    url = "https://am.i.mullvad.net/json";
                    json_attr = "ip";
                  }
                ])
              ])
              (concatLists [
                [
                  "https://wtfismyip.com/text"
                  "https://ident.me"
                  "https://ifconfig.co"
                  "https://ifconfig.me/ip"
                  "https://ipecho.net/plain"
                  "https://myexternalip.com/raw"
                  "https://www.trackip.net/ip"
                ]
                (map (srcOnly "ipv4") [
                  "https://api.ipify.org"
                  {
                    url = "https://httpbin.org/ip";
                    json_attr = "origin";
                  }
                ])
              ])
            ];
          };
          envVarFiles = {
            HETZNER_API_KEY = secrets.hetznerApiKey.decrypted.path;
            "LOGGING:NTFY:URL" = secrets.ntfyUrl.decrypted.path;
          };
        };
        secrix.services."dns-dynamic-primary-reflector".secrets = {
          # created at https://console.hetzner.com/projects/12914819/security/tokens
          # wl-paste | secr encrypt dns.boreth.pve.6nw.de nix/nixos/de.6nw/pve.boreth/dns/hetznerApiKey.age
          hetznerApiKey.encrypted.file = ./hetznerApiKey.age;
          # echo "https://ntfy.banananet.work/$(pwgen -s 32)" | secr encrypt dns.boreth.pve.6nw.de nix/nixos/de.6nw/pve.boreth/dns/ntfyUrl.age
          ntfyUrl.encrypted.file = ./ntfyUrl.age;
        };
      }
    )

    # config
    (
      { config, pkgs, ... }:
      {
        environment.systemPackages = [
          config.services.bind.package # for nsupdate & rndc
        ];
        networking = {
          hostName = "dns";
          domain = "boreth.pve.6nw.de";
          firewall = {
            allowedTCPPorts = singleton 53;
            allowedUDPPorts = singleton 53;
          };
          # secondaries authorize AXFR/IFXR/NOTIFYs by source IP
          tempAddresses = "disabled";
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
            "allglorytojesus.de." = {
              dynamic = true;
              update-policy = [
                ''grant "local-ddns" zonesub any''
              ];
              initialContent = ''
                $ORIGIN allglorytojesus.de.
                $TTL 3600
                @ IN SOA dns.boreth.pve.6nw.de. hostmaster.allglorytojesus.de. 1000 24h 2h 6w 1h
                ${concatMapped "\n" (attrNames hetznerSecondaryServers) (name: ''
                  @ IN NS ${name}
                '')}
              '';
              extraConfig = ''
                also-notify {
                  ${concatMapped "\n" hetznerSecondaryServerIPs (ip: ''
                    ${ip};
                  '')}
                };
              '';
            };
          };
          # transfer ACL of the dynamic zone (upstream attr, not part of zonesExt)
          zones."allglorytojesus.de.".slaves = hetznerSecondaryServerIPs;
        };
        secrix.services."bind".secrets = {
          # tsig-keygen -a hmac-sha512 router.boreth.pve.6nw.de. | secr encrypt dns.boreth.pve.6nw.de --system router.boreth.pve.6nw.de
          "tsig_router.boreth.pve.6nw.de.".encrypted.file = ./tsig_router.boreth.pve.6nw.de.age;
        };
        x-banananetwork = {
          useable.enable = true;
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
