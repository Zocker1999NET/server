{ libBNet, self, ... }@flakeArg:
let
  inherit (libBNet.modules) importsApplyMods;
in
{
  modules = importsApplyMods [

    # config
    self.outputs.nixosModules.router
    (
      { config, ... }:
      let
        outboundDNS = {
          # normal
          cloudflare = [
            # Cloudflare (default)
            "2606:4700:4700::1111"
            "2606:4700:4700::1001"
            "1.1.1.1"
            "1.0.0.1"
          ];
          quad9 = [
            # Quad9 (default)
            "2620:fe::fe"
            "2620:fe::9"
            "9.9.9.9"
            "149.112.112.112"
          ];
          home = [
            # resolvers at home
            "10.11.11.10"
            "10.11.11.1"
          ];
          # secure (format compatible to Adguard Home)
          quad9_secure = [
            # Quad9 (Malware blocked, ECS enabled)
            "https://dns11.quad9.net/dns-query"
            "tls://dns11.quad9.net"
          ];
          cloudflare_secure = [
            # Cloudflare (Malware blocked)
            "https://security.cloudflare-dns.com/dns-query"
            "tls://security.cloudflare-dns.com"
          ];
        };
      in
      {
        networking = {
          hostName = "router";
          domain = "boreth.pve.6nw.de";
        };
        services.tailscale = {
          enable = true;
          authKeyFile = config.secrix.services.tailscaled-autoconnect.secrets.authKey.decrypted.path;
          openFirewall = true;
          setFlags = {
            advertise-exit-node = true;
            hostname = "router-boreth";
          };
          # ensure all flags are already effective from first launch
          upFlags = config.services.tailscale.setFlags // {
            advertise-tags = [
              "tag:none"
              "tag:iperf3"
            ];
          };
        };
        secrix.services.tailscaled-autoconnect.secrets.authKey.encrypted.file = ./tailscale-auth-key.age;
        # workaround to work with FRITZ!Box which releases a broken NTP answer via DHCPv6
        systemd.network.networks."10-wan0".dhcpV6Config.UseNTP = false;
        systemd.services.systemd-networkd.environment.SYSTEMD_LOG_LEVEL = "debug";
        x-banananetwork = {
          useable.enable = true;
          vmCommon.enable = true;

          routerVM = {
            enable = true;
            dns = {
              upstreams = outboundDNS.quad9_secure;
              fallbacks = outboundDNS.cloudflare_secure;
              bootstraps = with outboundDNS; quad9 ++ cloudflare ++ home;
              localFallbacks = with outboundDNS; home ++ quad9 ++ cloudflare;
              filterlists = [
                # malware lists
                "https://raw.githubusercontent.com/RPiList/specials/master/Blocklisten/malware"
                "https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt"
                "https://v.firebog.net/hosts/Prigent-Malware.txt"
                "https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADomains.txt"
                "https://osint.digitalside.it/Threat-Intel/lists/latestdomains.txt"
                "https://urlhaus.abuse.ch/downloads/hostfile/"
              ];
              webui = {
                username = config.x-banananetwork.userName;
                password = "$2b$05$xuR2lh82.c2fqgJQFHAd0.ahyV5Pg6RCPkex89Dsw4KVebmH7qKBa";
              };
            };
          };
        };
      }
    )
    (import ./interfaces.nix flakeArg)

    # hardware
    self.outputs.nixosProfiles.pveGuest
    {
      x-banananetwork.routerVM = {
        interfaces = {
          "wan0".matchConfig.PermanentMACAddress = "BC:24:11:67:A6:D4";
          "lan0".matchConfig.PermanentMACAddress = "BC:24:11:66:CF:AC";
        };
      };
    }

    # installation state
    {
      system.stateVersion = "24.05";
      x-banananetwork.vmDisko = {
        generation = "ext4-1";
        mainDiskName = "main";
      };
      x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBd2Smf3STyRykTNVc+gluvL3B3r9LBIPS0ebDqon/EZ root@router.boreth.pve.6nw.de 2024-09-06";
    }

  ];
  system = "x86_64-linux";
}
