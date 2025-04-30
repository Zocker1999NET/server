{
  inputs,
  lib,
  outputs,
  ...
}@flakeArg:
{ pkgs, ... }@systemArg:
let
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

in
{

  empty = nixosIntegrationTest machines.empty {
    testScript = ''
      tested.wait_for_unit("default.target")
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
                firewall.input.checkDestination = false;
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
                workarounds.dhcpv6PrefixDelegationWithoutAddress = false;
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
          run(f"ip -4 addr show {interface} | grep -oP '(?<=inet\s)\d+(\.\d+)+(?=/\d+\s)' | head -n 1").strip(),
          run(f"ip -6 addr show {interface} | grep -oP '(?<=inet6\s)(?!f[cde])[\da-f:]+(?=/\d+\s(?!.*temporary))' | head -n 1").strip(),
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
        isp.wait_for_unit("kea-dhcp6-server.service")

        # server
        server.wait_for_unit("static-web-server.service")
        hasIp(server, "eth1", "10.1.", "2001:db8:1:1:")

        # router
        router.wait_for_unit("default.target")
        debug_out(router, "ip addr show")
        router.wait_for_unit("network-online.target")
        router.succeed("ip link show dev wan0")
        router.succeed("ip link show dev lan0")
        hasIp(router, "wan0", "10.1.0.", "2001:db8:1:1:")
        hasIp(router, "lan0", "10.32.1.1/24 ", ipv6_prefix)
        router.wait_for_unit("nft-update-addresses.service", None, 5)

        # client
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

}
