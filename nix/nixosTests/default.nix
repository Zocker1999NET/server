{
  inputs,
  lib,
  outputs,
  ...
}@flakeArg:
{ pkgs, ... }@systemArg:
let
  # import only simple flake lib functions (favorize machine specific lib for more realistic testing)
  inherit (lib.lists) singleton;
  # (end)
  libO = inputs.nixpkgs.lib;
  machines = outputs.nixosConfigurations;
  qemu-common = import "${inputs.nixpkgs}/nixos/lib/qemu-common.nix" {
    lib = libO;
    inherit pkgs;
  };
  qemuNicMac =
    config: netIdx: # according to virtualisation.vlans
    let
      nodeNum = config.virtualisation.test.nodeNumber;
      vlanNet = builtins.elemAt config.virtualisation.vlans netIdx;
    in
    qemu-common.qemuNicMac vlanNet nodeNum;
  # copied from qemu-common.nix
  zeroPad =
    n:
    lib.optionalString (n < 16) "0"
    + (if n > 255 then throw "Can't have more than 255 nets or nodes!" else lib.toHexString n);
  # TODO upstream variant of that into qemu-common.nix
  qemuSLAAC =
    config: netIdx: # according to virtualisation.vlans
    let
      nodeNum = config.virtualisation.test.nodeNumber;
      vlanNet = builtins.elemAt config.virtualisation.vlans netIdx;
    in
    "5054:ff:fe12:${zeroPad vlanNet}${zeroPad nodeNum}";
  nixosTest =
    {
      # can only accept attrs as nodes configs
      nodes ? { },
      config ? { },
      ...
    }@args:
    let
      extConfig.config = {
        # speeds up builds & prevents assertions to break
        boot.loader.grub.enable = lib.mkForce false;
        boot.loader.systemd-boot.enable = lib.mkForce false;
        # packages for testing
        environment.systemPackages = with pkgs; [
          curl
          dig
          jq
        ];
        # disable all VM test network magic (TODO extract)
        networking = {
          interfaces = lib.mkForce { };
          extraHosts = lib.mkForce "";
          #hostName = lib.mkDefault name;
          useNetworkd = lib.mkDefault true;
        };
        # disable test driver backdoor interface (hacky)
        systemd.network = {
          # esp. this is required to have no Internet in interactive tests
          networks."20-backdoor" = {
            matchConfig.Name = "eth0";
            linkConfig.Unmanaged = true;
          };
          wait-online.ignoredInterfaces = lib.singleton "eth0";
        };
        # avoid warnings because of modified root password
        users.users.root = {
          # TODO which of those is set by the test driver?
          #hashedPassword = lib.modules.mkTestOverride null;
          #hashedPasswordFile = lib.modules.mkTestOverride null;
          #initialPassword = lib.modules.mkTestOverride null;
          #initialHashedPassword = lib.modules.mkTestOverride null;
        };
      };
    in
    pkgs.nixosTest (
      args
      // {
        nodes = lib.flip builtins.mapAttrs nodes (
          name: node: {
            imports = [
              node
              extConfig
            ];
          }
        );
      }
    );
  nixosIntegrationTest =
    tested: # from machines
    {
      name ? "full",
      testScript ? "",
      # can only accept attrs as nodes configs
      nodes ? { },
      config ? { },
      ...
    }@args:
    let
      hostName = tested.config.networking.hostName;
      fqdn = tested.config.networking.fqdn;
    in
    nixosTest (
      {
        name = "${fqdn}_integration-test";
        nodes = nodes // {
          tested = {
            imports = tested._banananetwork_systemArgs.modules;
            config._module.args.flake = flakeArg;
          };
        };
        testScript = ''
          # fix access as that name
          tested = ${builtins.replaceStrings [ "-" ] [ "_" ] hostName}
          # fast bootup
          start_all()
          ${testScript}
        '';
      }
      // (builtins.removeAttrs args [
        "name"
        "nodes"
        "testScript"
        "config"
      ])
    );

  # TODO migrate docs test to a simpler documentation builder flake check (is not required to be a full blown NixOS test)
  nixosDocTest =
    {
      # local options (blacklisted below)
      modules,
      config ? { },
      # (required) passthrough options
      name,
      ...
    }@args:
    nixosTest (
      {
        nodes.tested = {
          imports = modules;
          config = config // {
            documentation.nixos.includeAllModules = true;
          };
        };
        testScript = ""; # VM execution not required, build is sufficient
      }
      // (builtins.removeAttrs args [
        "config"
        "modules"
      ])
    );

in
{

  empty = nixosIntegrationTest machines.empty {
    testScript = ''
      tested.wait_for_unit("default.target")
    '';
  };

  # === flake input extended/integration tests
  # (maybe upstream someday)

  # most basic, verifies my own testing method as already upstreamed
  docs_includeAllModules_nixpkgs = nixosDocTest {
    name = "docs_includeAllModules_nixpkgs";
    modules = [ ]; # nixpkgs already included
  };
  # input-specific doc tests
  docs_includeAllModules_disko = nixosDocTest {
    name = "docs_includeAllModules_disko";
    modules = singleton inputs.disko.nixosModules.disko;
  };
  docs_includeAllModules_home-manager = nixosDocTest {
    name = "docs_includeAllModules_home-manager";
    modules = singleton inputs.home-manager.nixosModules.home-manager;
  };
  docs_includeAllModules_impermanence = nixosDocTest {
    name = "docs_includeAllModules_impermanence";
    modules = singleton inputs.impermanence.nixosModules.impermanence;
  };
  docs_includeAllModules_secrix = nixosDocTest {
    name = "docs_includeAllModules_secrix";
    modules = singleton inputs.secrix.nixosModules.secrix;
  };

  # == own module tests

  # all module doc test
  # - indicates missing dependency-specific test or failure in banananetwork module
  docs_includeAllModules_banananetwork = nixosDocTest {
    name = "docs_includeAllModules_banananetwork";
    modules = [
      outputs.nixosModules.withDepends # bnet modules require their dependencies
      outputs.nixosModules.myOptions
      outputs.nixosProfiles.common # TODO remove when x-banananetwork.allCommon gets removed
    ];
  };

  # own home-manager module doc test
  docs_includeAllModules_hm_banananetwork = nixosDocTest {
    name = "docs_includeAllModules_hm_banananetwork";
    modules = [
      inputs.home-manager.nixosModules.home-manager
      { home-manager.sharedModules = [ outputs.homeManagerModules.default ]; }
    ];
  };

  getty-helpLine-sshPublicHostKey = nixosTest {
    name = "getty-helpLine-sshPublicHostKey";
    nodes.node = {
      imports = [
        outputs.nixosProfiles.common
        outputs.nixosModules.withDepends
      ];
      services.getty.dynamicHelpLine.sshPublicHostKey.enable = true;
      # required for host keys to be generated and displayed
      services.openssh.enable = true;
      # answer options with missing defaults
      x-banananetwork.sshPublicKeys = [ ];
    };
    testScript = ''
      node.wait_for_unit("getty@tty1.service")
      service_name = "getty-helpLine-sshPublicHostKey.service"
      node.succeed(f"systemctl is-enabled {service_name}")
      node.fail(f"systemctl is-active {service_name}")
      node.fail(f"systemctl is-failed {service_name}")
      node.wait_until_tty_matches("1", r"\n\d+\s+[A-Z0-9]+:[A-Za-z0-9+/=]+\s+root@node\s+\([A-Z0-9]+\)\s+\n", 10)
    '';
  };

  router = nixosTest {
    name = "router";

    interactive.nodes = {
      client.virtualisation.vlans = lib.mkForce [
        #
        101
      ];
      ispShark = {
        virtualisation.vlans = [
          2
          101
        ];
        networking.useDHCP = false;
        systemd.network = {
          enable = true;
          wait-online.enable = false; # will bug out
          netdevs."10-bridge".netdevConfig = {
            Kind = "bridge";
            Name = "br0";
          };
          networks."10-bridging" = {
            matchConfig.Name = "eth1 eth2";
            networkConfig.Bridge = "br0";
          };
          networks."10-bridge" = {
            matchConfig.Name = "br0";
            networkConfig = {
              DHCP = "no";
              IPv6AcceptRA = false;
            };
          };
        };
        programs.wireshark.enable = true;
        services.cage = {
          enable = true;
          user = "root";
          program = "${lib.getExe pkgs.wireshark} -k -i br0";
        };
        virtualisation.cores = 2;
        virtualisation.memorySize = 2 * 1024; # MiB
      };
      #client = {
      #  services.cage = {
      #    enable = true;
      #    user = "root";
      #    program = "${lib.getExe pkgs.firefox} http://10.32.1.1";
      #  };
      #  virtualisation.cores = 2;
      #  virtualisation.memorySize = 2 * 1024; # MiB
      #};
    };

    nodes.router =
      { config, nodes, ... }:
      {
        imports = [
          outputs.nixosProfiles.common
          outputs.nixosModules.withDepends
        ];
        environment.systemPackages = with pkgs; [
          curl
          dnsutils
        ];
        virtualisation.vlans = [
          1
          2
        ];
        services.openssh.enable = true; # enable SSH for testing reachability
        x-banananetwork.routerVM = {
          enable = true;
          interfaces =
            let
              defaults = {
                #firewall.blackhole.sets.documentation.all = false;
                # TODO add test case differentiating for this
                #firewall.input.checkDestination = false;
              };
              insertDefaults = builtins.mapAttrs (
                _: v:
                lib.mkMerge [
                  defaults
                  v
                ]
              );
            in
            insertDefaults {
              wan0 = {
                kind = "wan-rfc7084";
                matchConfig.PermanentMACAddress = qemuNicMac config 0;
                # TODO build test so it requires:
                workarounds.dhcpv6IsAvmFritzBox = false;
              };
              lan0 = {
                kind = "lan-rfc7084";
                matchConfig.PermanentMACAddress = qemuNicMac config 1;
                routing = {
                  domain = "local";
                  ipv4Address = "10.32.1.1/24";
                  upstream = "wan0";
                };
                devices = {
                  "client" = {
                    mac = qemuNicMac nodes.client 0;
                    staticIPv4 = "10.32.1.22";
                    forwardedPorts.http-test = {
                      wanPort = 8080;
                      lanPort = 80;
                    };
                  };
                  # random devices
                  "other" = {
                    mac = "AA:BB:CC:DD:EE:FF";
                    # without port forwardings -> config failed before
                  };
                };
                # TODO until https://github.com/systemd/systemd/issues/29651 is fixed:
                networkd.ipv6SendRAConfig.RouterLifetimeSec = lib.mkForce 30; # to speed up test
              };
            };
          dns = lib.mkForce {
            upstreams = [
              "10.1.0.1"
              "2001:db8:1:1::1"
            ];
            bootstraps = config.x-banananetwork.routerVM.dns.upstreams;
            fallbacks = [ ];
            webui.password = ""; # invalid password
          };
        };
        # more overwrites to make that isolated test feasable
        services.adguardhome.settings = {
          dns.enable_dnssec = lib.mkForce false;
          filtering.safebrowsing_enabled = lib.mkForce false;
          filters = lib.mkForce [ ];
        };
        # answer options with missing defaults
        x-banananetwork.sshPublicKeys = [ ];
      };

    nodes.isp =
      { nodes, ... }:
      {
        imports = lib.singleton ./isp.nix;
        config = {
          staticLeases = {
            server = {
              mac = qemuNicMac nodes.server 0;
              ipv4 = "10.1.1.1";
            };
          };
          virtualisation.vlans = lib.singleton 1;
        };
      };
    nodes.server.config = {
      environment.systemPackages = lib.singleton pkgs.openssh;
      networking.firewall.enable = false; # for testing
      networking.useNetworkd = true;
      services.static-web-server = {
        enable = true;
        listen = "80";
        root = builtins.toString (pkgs.writeTextDir "test" "Hello from the Internet!");
      };
      virtualisation.vlans = lib.singleton 1;
    };
    nodes.client.config = {
      environment.systemPackages = lib.singleton pkgs.openssh;
      networking.firewall.enable = false; # for testing
      networking.useNetworkd = true;
      services.static-web-server = {
        enable = true;
        listen = "80";
        root = builtins.toString (pkgs.writeTextDir "test" "Hello from your home!");
      };
      virtualisation.vlans = lib.singleton 2;
    };
    testScript = ''
      from shlex import quote
      def debug_out(node, cmd):
        print(f"testscript: {node.name} : {cmd}")
        print(node.execute(cmd)[1])
      def switch_to(node, name):
        # On first switch, this will create a symlink to the current system so that we can quickly switch between derivations
        root_specs = "/tmp/specialisation"
        node.execute(
          f"test -e {root_specs}"
          f" || ln -s $(readlink /run/current-system)/specialisation {root_specs}"
        )
        switcher_path = f"/run/current-system/specialisation/{name}/bin/switch-to-configuration"
        rc, _ = node.execute(f"test -e '{switcher_path}'")
        if rc > 0:
          switcher_path = f"/tmp/specialisation/{name}/bin/switch-to-configuration"
        node.succeed(f"{switcher_path} test")
      def hasIp4(machine, interface, ip):
        machine.wait_until_succeeds(f"ip -4 addr show dev {interface} | grep -F 'inet {ip}'", 5)
      def hasIp6(machine, interface, ip):
        machine.wait_until_succeeds(f"ip -6 addr show dev {interface} | grep -F 'inet6 {ip}'", 5)
      def hasIp(machine, interface, ip4, ip6):
        hasIp4(machine, interface, ip4)
        hasIp6(machine, interface, ip6)
      def getIp(machine, interface):
        run = lambda cmd: machine.succeed(cmd)
        return (
          run(rf"ip -4 addr show {interface} | grep -oP '(?<=inet\s)\d+(\.\d+)+(?=/\d+\s)' | head -n 1").strip(),
          run(rf"ip -6 addr show {interface} | grep -oP '(?<=inet6\s)(?!f[cde])[\da-f:]+(?=/\d+\s(?!.*temporary))' | head -n 1").strip(),
        )
      def dig(query, response):
        return f"dig {query} | tee /dev/stderr | grep -P {quote(response)} >/dev/null"
      def both(execFun, cmdFun, target, *args, **kwargs):
        for t in target:
          execFun(cmdFun(t, *args, **kwargs))
      def ping(target):
        return f"ping -A -c 2 -n -w 2 {target}"
      def curl(target, result, port=None):
        portPart = "" if port is None else f":{port}"
        if ":" in target:
          target = f"[{target}]"
        url = f"http://{target}{portPart}/test"
        return f"curl --connect-timeout 2 --silent {url} | grep -F 'Hello from {result}!'"
      def ssh(target):
        return f"ssh-keyscan {target}"

      def test_suite(ipv6_prefix):
        isp.wait_for_unit("default.target")
        isp.wait_for_unit("kea-dhcp6-server.service")

        # server
        server.wait_for_unit("default.target")
        server.wait_for_unit("static-web-server.service")
        hasIp(server, "eth1", "10.1.", "2001:db8:1:1:")

        # router
        router.wait_for_unit("default.target")
        debug_out(router, "ip addr show")

        # network-online.target is not necessarily pulled in by another service
        # but the router should be able to fullfil it
        router.execute("systemctl start network-online.target")
        router.wait_for_unit("network-online.target")

        router.succeed("ip link show dev wan0")
        router.succeed("ip link show dev lan0")
        hasIp(router, "wan0", "10.1.0.", "2001:db8:1:1:")
        hasIp(router, "lan0", "10.32.1.1/24 ", ipv6_prefix)
        router.wait_for_unit("nft-update-addresses.service", None, 5)

        # client
        client.wait_for_unit("default.target")
        hasIp(client, "eth1", "10.32.1.", ipv6_prefix)
        debug_out(client, "ip addr show")

        # gather IPs
        serverIP = getIp(server, "eth1")
        routerWanIP = getIp(router, "wan0")
        routerLanIP = getIp(router, "lan0")
        clientIP = getIp(client, "eth1")
        print("testscript: collected IPs")
        for ip in (serverIP, routerWanIP, routerLanIP, clientIP):
          print(ip)

        # SSH reachable
        both(server.succeed, ssh, routerWanIP)
        both(client.succeed, ssh, routerLanIP)
        both(client.succeed, ssh, routerWanIP)
        # TODO this works, now also test after switch to trivialNetwork

        # DNS tests
        dnsReqs = {
          "isp.test. A": r"10\.1\.0\.1",
          "isp.test. AAAA": r"2001:db8:1:1::1",
          "isp.test. TXT": r"hello nix",
        }
        for m in (isp, server, router, client):
          for req, resp in dnsReqs.items():
            m.succeed(dig(req, resp))

        # ping router -> _
        both(router.succeed, ping, serverIP)
        both(router.succeed, ping, clientIP)
        # ping client -> …
        both(client.succeed, ping, routerLanIP)
        both(client.succeed, ping, routerWanIP)
        both(client.succeed, ping, serverIP)
        # ping server -> …
        both(server.succeed, ping, routerWanIP)
        #both(server.fail, ping, routerLanIP) # TODO NixOS just allows all ICMP in by default
        both(server.fail, ping, clientIP)

        # curl tests
        for m in (server, client):
          m.wait_for_unit("static-web-server.service")
        ## all reach server
        for m in (isp, router, client):
          both(m.succeed, curl, serverIP, "the Internet")
        ## router -> client
        both(router.succeed, curl, clientIP, "your home", port=80)
        ## server -> client (v4)
        server.fail(curl(clientIP[0], "your home"))
        server.fail(curl(clientIP[0], "your home", port=8080))
        ## server -> client (v6)
        server.succeed(curl(clientIP[1], "your home"))
        server.fail(curl(clientIP[1], "your home", port=8080))
        ## server -> router
        both(server.fail, curl, routerWanIP, "your home")
        both(server.succeed, curl, routerWanIP, "your home", port=8080)
        both(server.fail, curl, routerLanIP, "your home")
        both(server.fail, curl, routerLanIP, "your home", port=8080)
        ## client -> router
        both(client.fail, curl, routerWanIP, "your home")
        both(client.succeed, curl, routerWanIP, "your home", port=8080) # NAT reflection
        both(client.fail, curl, routerLanIP, "your home")
        both(client.fail, curl, routerLanIP, "your home", port=8080)
        # TODO test that on IPv6 link-local DNAT is NOT applied

      start_all()
      test_suite("2001:db8:1111:")

      # IPv6 transation time test
      switch_to(isp, "secondPrefixDelegation")
      isp.wait_for_unit("kea-dhcp6-server.service")
      router.succeed("networkctl down wan0")
      router.wait_until_fails("ip -6 addr show | grep -F 2001:db8:1111:", 3)
      router.wait_until_fails("nft list ruleset | grep -F 2001:db8:1111:", 3)
      router.succeed("networkctl up wan0")
      router.wait_until_succeeds("nft list ruleset | grep -F 2001:db8:2a01:", 5)
      try:
        client.wait_until_fails("ip -6 addr show | grep -F 2001:db8:1111: | grep -vF ' deprecated '", 40)
      finally:
        debug_out(client, "ip addr show")
      test_suite("2001:db8:2a01:")

      # test firewall after nftables reload (flushes nftua sets)
      router.succeed("systemctl reload nftables.service")
      router.wait_for_unit("nft-update-addresses.service", None, 5)  # ensure unit still up
      test_suite("2001:db8:2a01:")

      # Test trivialNetwork specialisation
      # TODO
      #switch_to(router, "trivialNetwork")
      #serverIP = getIp(server, "eth1")
      #routerWanIP = getIp(router, "wan0")  # TODO get IP from any interface
      #clientIP = getIp(client, "eth1")
      #both(server.succeed, ssh, routerWanIP)
      ## verify that forwarding is disabled
      ## TODO add invalid route for IPv4 to to ensure remote routing is failing
      #both(server.fail, curl, routerWanIP, "your home", port=8080)
      #both(server.fail, curl, clientIP, "your home"))
      #both(client.fail, curl, serverIP, "the Internet")
    '';
  };

  /*
    environment.etc."octodns/config.yaml".text = lib.generators.toYAML { } {
      providers = {
        alpha = {
          class = "octodns_bind.AxfrSource";
          host = "127.0.0.1";
        };
        beta = {
          class = "octodns_bind.AxfrSource";
          host = "127.0.0.1";
        };
        zonefile = {
          class = "octodns_bind.ZoneFileProvider";
          directory = "/root";
          file_extension = ".zone";
        };
      };
      zones."example." = {
        sources = [
          "alpha"
          "beta"
        ];
        targets = [ "zonefile" ];
      };
    };
    environment.systemPackages = with pkgs; [
      (octodns.withProviders (ps: [
        #
        octodns-providers.bind
      ]))
    ];
  */

  bind-dynamic = nixosTest {
    name = "bind-dynamic";
    nodes.server = {
      imports = [
        outputs.nixosProfiles.common
        outputs.nixosModules.withDepends
      ];
      config = {
        environment.systemPackages = with pkgs; [ dnsutils ];
        networking.firewall.enable = false;
        services.bind = {
          enable = true;
          zonesExt."example." = {
            dynamic = true;
            update-policy = lib.singleton ''grant "local-ddns" zonesub any'';
            initialContent = ''
              $TTL 3600
              $ORIGIN example.
              @ IN SOA internet. hostmaster.internet. 1 12h 15m 3w 2h
              @ IN NS internet.
              alpha IN NS dns.alpha.example.
              dns.alpha.example. IN A 192.0.2.10
            '';
          };
        };
      };
    };
    testScript = ''
      server.wait_for_unit("bind.service")
      #server.succeed("dig @127.0.0.1 alpha.example. NS | grep 192.0.2.10")  # TODO remove, tests something else
      # check that data does not already exist
      server.succeed("dig @127.0.0.1 +short test.example. TXT | (! grep -iF HeLLoWoRld)")
      # attempt dns update
      server.succeed('echo "update add test.example. 3600 TXT HeLLoWoRld\nsend\n" | nsupdate -l')
      server.succeed("dig @127.0.0.1 +short test.example. TXT | grep -iF HeLLoWoRld")
      # check persistence after service restart
      server.systemctl("stop bind.service")
      server.systemctl("start bind.service")
      server.wait_for_unit("bind.service")
      server.succeed("dig @127.0.0.1 +short test.example. TXT | grep -iF HeLLoWoRld")
    '';
  };

  # TODO (test) check "tailscale status" for "# Health check:" line, indicating an issue
  # - test that with a route enabled (see https://github.com/tailscale/tailscale/issues/13863)

  router-tailscale =
    let
      tls-cert = pkgs.runCommand "selfSignedCerts" { buildInputs = [ pkgs.openssl ]; } ''
        openssl req \
          -x509 -newkey rsa:4096 -sha256 -days 365 \
          -nodes -out cert.pem -keyout key.pem \
          -subj '/CN=headscale.test' -addext "subjectAltName=DNS:headscale.test"

        mkdir -p $out
        cp key.pem cert.pem $out
      '';
      peer = {
        services.tailscale = {
          enable = true;
          extraDaemonFlags = lib.singleton "--no-logs-no-support";
        };
        security.pki.certificateFiles = [ "${tls-cert}/cert.pem" ];
      };
      client = {
        networking.useNetworkd = true;
      };
      echoPort = 8088;
      echoService = {
        networking.firewall.allowedTCPPorts = [ echoPort ];
        systemd.services."echo-service" = {
          serviceConfig.ExecStart = "${lib.getExe pkgs.python3} ${./router/echo_service.py} --port ${toString echoPort}";
          wantedBy = lib.singleton "multi-user.target";
        };
      };
      headscalePort = 8080;
      stunPort = 3478;
    in
    nixosTest {
      name = "router-tailscale";
      nodes = {
        isp =
          { nodes, ... }:
          {
            imports = lib.singleton ./isp.nix;
            config = {
              staticLeases = {
                headscale = {
                  mac = qemuNicMac nodes.headscale 0;
                  ipv4 = "10.1.1.10";
                };
              };
              virtualisation.vlans = lib.singleton 1;
            };
          };
        headscale = {
          environment.systemPackages = [ pkgs.headscale ];
          networking.useNetworkd = true;
          networking.firewall = {
            allowedTCPPorts = [
              80
              443
            ];
            allowedUDPPorts = [ stunPort ];
          };
          services = {
            # config mostly copied from <nixpkgs>/nixos/tests/headscale.nix
            headscale = {
              enable = true;
              port = headscalePort;
              settings = {
                server_url = "https://headscale.test";
                ip_prefixes = [
                  "100.64.0.0/10"
                  "fd7a:115c:a1e0::/48"
                ];
                derp.server = {
                  enabled = true;
                  region_id = 999;
                  stun_listen_addr = "0.0.0.0:${toString stunPort}";
                };
                dns.base_domain = "example"; # default is .test otherwise
              };
            };
            nginx = {
              enable = true;
              virtualHosts.headscale = {
                addSSL = true;
                sslCertificate = "${tls-cert}/cert.pem";
                sslCertificateKey = "${tls-cert}/key.pem";
                locations."/" = {
                  proxyPass = "http://127.0.0.1:${toString headscalePort}";
                  proxyWebsockets = true;
                };
              };
            };
          };
          virtualisation.vlans = lib.singleton 1;
        };
        peer = {
          imports = [
            echoService
            peer
          ];
          services.tailscale.extraSetFlags = [
            "--accept-routes"
          ];
        };
        router =
          { config, nodes, ... }:
          {
            imports = [
              outputs.nixosProfiles.common
              outputs.nixosModules.withDepends
              peer
            ];
            services.tailscale.extraSetFlags = [
              # TODO test for a working exit node routing
              "--advertise-exit-node"
            ];
            virtualisation.vlans = [
              1
              2
              3
              4
              5
            ];
            x-banananetwork.routerVM = {
              enable = true;
              interfaces = {
                wan0 = {
                  kind = "wan-rfc7084";
                  matchConfig.PermanentMACAddress = qemuNicMac config 0;
                  # TODO build test so it requires:
                  workarounds.dhcpv6IsAvmFritzBox = false;
                  workarounds.dhcpv6PrefixDelegationWithoutAddress = false;
                };
                # without Tailnet access
                lan0 = {
                  kind = "lan-rfc7084";
                  matchConfig.PermanentMACAddress = qemuNicMac config 1;
                  routing = {
                    domain = "local";
                    ipv4Address = "10.32.0.1/24";
                    ipv6ULAPrefix = "fd69:dead:beef:0::/64";
                    upstream = "wan0";
                  };
                };
                # with Tailnet access (lan1 srcnat)
                lan1 = {
                  kind = "lan-rfc7084";
                  matchConfig.PermanentMACAddress = qemuNicMac config 2;
                  routing = {
                    domain = "local";
                    ipv4Address = "10.32.1.1/24";
                    ipv6ULAPrefix = "fd69:dead:beef:1::/64";
                    natted = lib.singleton "tailscale0";
                    upstream = "wan0";
                  };
                };
                # with Tailnet access (Tailscale srcnat)
                lan2 = {
                  kind = "lan-rfc7084";
                  matchConfig.PermanentMACAddress = qemuNicMac config 3;
                  routing = {
                    domain = "local";
                    ipv4Address = "10.32.2.1/24";
                    ipv6ULAPrefix = "fd69:dead:beef:2::/64";
                    upstream = "wan0";
                  };
                };
                # with Tailnet access (plain)
                lan3 = {
                  kind = "lan-rfc7084";
                  matchConfig.PermanentMACAddress = qemuNicMac config 4;
                  routing = {
                    domain = "local";
                    ipv4Address = "10.32.3.1/24";
                    ipv6ULAPrefix = "fd69:dead:beef:3::/64";
                    plain = lib.singleton "tailscale0";
                    upstream = "wan0";
                  };
                };
                # TODO redesign "user interface"
                tailscale0 = {
                  # TODO (feature) announce these routes via Tailscale
                  routing = {
                    plain = [
                      "lan3"
                    ];
                    natted = [
                      "lan2"
                    ];
                  };
                };
              };
              dns = lib.mkForce {
                upstreams = [
                  "10.1.0.1"
                  "2001:db8:1:1::1"
                ];
                bootstraps = config.x-banananetwork.routerVM.dns.upstreams;
                fallbacks = [ ];
                webui.password = ""; # invalid password
              };
            };
            networking.nftables = {
              traceToJournal = true;
              traceIPv4 = [
                ''100.64.0.0/10 . 100.64.0.0/10 . icmp . 0/0 . 0/0'' # "tailscale0"
                ''0.0.0.0/0 . 100.64.0.0/10 . icmp . 0/0 . 0/0'' # "lan0"
                ''0.0.0.0/0 . 100.64.0.0/10 . icmp . 0/0 . 0/0'' # "lan1"
              ];
              traceIPv6 = [
                ''fd00::/8 . fd00::/8 . ipv6-icmp . 0/0 . 0/0'' # "tailscale0"
                ''::/0 . fd00::/8 . ipv6-icmp . 0/0 . 0/0'' # "lan0"
                ''::/0 . fd00::/8 . ipv6-icmp . 0/0 . 0/0'' # "lan1"
              ];
            };
            # more overwrites to make that isolated test feasible
            services.adguardhome.settings = {
              dns.enable_dnssec = lib.mkForce false;
              filtering.safebrowsing_enabled = lib.mkForce false;
              filters = lib.mkForce [ ];
            };
            # answer options with missing defaults
            x-banananetwork.sshPublicKeys = [ ];
          };
        client0 = {
          imports = [
            client
          ];
          virtualisation.vlans = lib.singleton 2;
        };
        client1 = {
          imports = [
            client
          ];
          virtualisation.vlans = lib.singleton 3;
        };
        client2 = {
          imports = [
            client
            echoService
          ];
          virtualisation.vlans = lib.singleton 4;
        };
        client3 = {
          imports = [
            client
            echoService
          ];
          virtualisation.vlans = lib.singleton 5;
        };
      };
      testScript = ''
        from ipaddress import ip_address, ip_network

        def getIp(machine, interface):
          run = lambda cmd: machine.succeed(cmd)
          return (
            run(rf"ip -4 addr show {interface} | grep -oP '(?<=inet\s)\d+(\.\d+)+(?=/\d+\s)' | head -n 1").strip(),
            # here, we actually require the use of the link-local addresses
            run(rf"ip -6 addr show {interface} | grep -oP '(?<=inet6\s)fd[\da-f:]+(?=/\d+\s(?!.*temporary))' | head -n 1").strip(),
          )
        def ping(target):
          return f"ping -A -c 2 -n -w 2 {target}"
        def test_echo(node, target, compare, expected=True):
          if ":" in target:
            target = f"[{target}]"
          echoed = node.succeed(f"curl --silent http://{target}:${toString echoPort}").strip()
          if ":" in target:
            # in case of IPv6, clients may also use their Privacy Extension addresses
            # still, we can verify that no NAT was applied by checking the first 64 bit
            compare_state = ip_network(f"{compare}/64", strict=False) == ip_network(f"{echoed}/64", strict=False)
          else:
            compare_state = ip_address(compare) == ip_address(echoed)
          assert compare_state == expected, f"compared to {compare}, got {echoed}"

        start_all()
        headscale.wait_for_unit("headscale.service")
        headscale.wait_for_open_port(${toString headscalePort}, timeout=30)  # ensure headscale is ready for requests
        headscale.wait_for_open_port(443, timeout=30)  # ensure nginx is ready to forward requests

        # Create headscale user and preauth-key
        headscale.succeed("headscale users create test")
        authkey = headscale.succeed("headscale preauthkeys -u test create --reusable").rstrip("\r\n")

        # ensure that ISP network is ready
        isp.wait_for_unit("default.target")
        peer.wait_for_unit("default.target")
        router.wait_for_unit("default.target")

        # Connect peers
        # (authkey should only be hexdecimal, hence no escape required)
        # (tailscaled-set.service needs to be started again, because the settings it applied are reset on initial "tailscale up")
        up_cmd = f"tailscale up --login-server 'https://headscale.test' --auth-key {authkey} --accept-dns=false && systemctl start tailscaled-set"
        peer.succeed(up_cmd)
        router.succeed(up_cmd)

        # Verify reachability inside tailnet
        peer.wait_until_succeeds("tailscale ping router", 10)
        router.wait_until_succeeds("tailscale ping peer", 10)

        # accept all routes
        routes = headscale.succeed("headscale routes list --output json | jq '.[].id'").rstrip("\r\n").split("\n")
        for route in routes:
          headscale.succeed(f"headscale routes enable -r {route}")
        # ensure router is acknowledged as possible exit node
        peer.wait_until_succeeds("tailscale exit-node list | grep router", 10)

        # ensure all are ready (esp. clients)
        for m in machines:
          m.wait_for_unit("default.target")

        client0_ip_both = getIp(client0, "eth1")
        client1_ip_both = getIp(client1, "eth1")
        client2_ip_both = getIp(client2, "eth1")
        client3_ip_both = getIp(client3, "eth1")

        for ip_kind in ("ipv4", "ipv6"):
          ip_arg = "-4" if ip_kind == "ipv4" else "-6"
          ip_idx = 0 if ip_kind == "ipv4" else 1
          peer_ip = router.succeed(f"tailscale ip {ip_arg} peer").strip()
          router_ip = peer.succeed(f"tailscale ip {ip_arg} router").strip()
          client0_ip = client0_ip_both[ip_idx]
          client1_ip = client1_ip_both[ip_idx]
          client2_ip = client2_ip_both[ip_idx]
          client3_ip = client3_ip_both[ip_idx]

          # internal connectivity
          peer.succeed(ping(router_ip))
          router.succeed(ping(peer_ip))
          test_echo(router, peer_ip, router_ip)

          # without Tailnet access
          client0.fail(ping(router_ip))
          client0.fail(ping(peer_ip))
          peer.fail(ping(client0_ip))

          # with Tailnet access (lan srcnat)
          client1.succeed(ping(router_ip))
          client1.succeed(ping(peer_ip))
          test_echo(client1, peer_ip, client1_ip, expected=False)
          peer.fail(ping(client1_ip))

          # with Tailnet access (Tailscale srcnat)
          client2.fail(ping(router_ip))
          client2.fail(ping(peer_ip))
          peer.succeed(ping(client2_ip))
          test_echo(peer, client2_ip, peer_ip, expected=False)

          # with Tailnet access (plain)
          client3.succeed(ping(router_ip))
          client3.succeed(ping(peer_ip))
          test_echo(client3, peer_ip, client3_ip)
          peer.succeed(ping(client3_ip))
          test_echo(peer, client3_ip, peer_ip)
      '';
    };

}
