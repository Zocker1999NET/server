{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) attrValues concatStringsSep filter;
  inherit (lib) types;
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkForce;
  inherit (lib.options) mkOption;
  inherit (lib.strings) makeBinPath;
  inherit (lib.trivial) pipe;
in
# TODO separate internet & router
{
  options.staticLeases = mkOption {
    description = "static leases + DNS records";
    type = types.attrsOf (
      types.submodule (
        { name, ... }:
        {
          options = {
            name = mkOption { default = name; };
            mac = mkOption { type = types.str; };
            ipv4 = mkOption { type = types.nullOr types.str; };
          };
        }
      )
    );
  };
  config = {
    boot.kernel.sysctl = {
      "net.ipv4.conf.default.forwarding" = true;
      "net.ipv4.conf.all.forwarding" = true;
      "net.ipv6.conf.default.forwarding" = true;
      "net.ipv6.conf.all.forwarding" = true;
    };
    networking = {
      firewall.enable = false; # for testing
      nameservers = singleton "127.0.0.1";
      tempAddresses = "disabled";
      useDHCP = false;
      useNetworkd = false; # avoid NixOS default configs, see manual below
    };
    services.bind = {
      enable = true;
      # allow recursion, just to make systemd-resolved happy (otherwise it ignores bind)
      cacheNetworks = [
        "0.0.0.0/0"
        "::/0"
      ];
      extraOptions = "empty-zones-enable no;";
      forwarders = [ ]; # no forwarders
      zones."." = {
        master = true;
        file = pkgs.writeText "root.zone" ''
          $TTL 3600
          . IN SOA internet. hostmaster.internet. 1 12h 15m 3w 2h
          . NS isp.test.
          $ORIGIN test.
          isp A 10.1.0.1
          isp AAAA 2001:db8:1:1::1
          isp TXT "hello nix"
          ${pipe config.staticLeases [
            attrValues
            (filter (x: x.ipv4 != null))
            (map (x: ''
              ${x.name} A ${x.ipv4}
            ''))
            (concatStringsSep "")
          ]}
        '';
      };
    };
    services.resolved.enable = false;
    systemd.network = {
      enable = true;
      wait-online.enable = false; # might bug out
      networks."10-eth1" = {
        matchConfig.Name = "eth1";
        networkConfig = {
          DHCPServer = true;
          LinkLocalAddressing = "ipv6";
          IPv6LinkLocalAddressGenerationMode = "eui64";
          IPv6AcceptRA = false;
          IPv6SendRA = true;
        };
        dhcpServerConfig = {
          ServerAddress = "10.1.0.1/16";
          PoolSize = 256; # /24
          DNS = "_server_address";
        };
        dhcpServerStaticLeases = pipe config.staticLeases [
          attrValues
          (filter (x: x.ipv4 != null))
          (map (
            { mac, ipv4, ... }:
            {
              dhcpServerStaticLeaseConfig = {
                MACAddress = mac;
                Address = ipv4;
              };
            }
          ))
        ];
        ipv6SendRAConfig = {
          DNS = "_server_address";
          # RFC 7084, WPD-4: O flag MUST be sufficient
          Managed = false;
          OtherInformation = true;
        };
        ipv6Prefixes = singleton {
          ipv6PrefixConfig = {
            Prefix = "2001:db8:1:1::/64";
            Assign = true;
            Token = "static:::1";
          };
        };
      };
    };
    systemd.services.kea-dhcp6-server.serviceConfig = {
      AmbientCapabilities = [ "CAP_NET_ADMIN" ];
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
    };
    services.kea.dhcp6 = {
      enable = true;
      settings = {
        # taken from <nixpkgs>/nixos/tests/systemd-networkd-ipv6-prefix-delegation.nix
        hooks-libraries = singleton {
          library = "${pkgs.kea}/lib/kea/hooks/libdhcp_run_script.so";
          parameters = {
            name = pkgs.writeShellScript "kea-run-hooks" ''
              export PATH="${
                makeBinPath [
                  pkgs.coreutils
                  pkgs.iproute2
                ]
              }"
              set -euxo pipefail
              leases6_committed() {
                for i in $(seq $LEASES6_SIZE); do
                  idx=$((i-1))
                  prefix_var="LEASES6_AT''${idx}_ADDRESS"
                  plen_var="LEASES6_AT''${idx}_PREFIX_LEN"
                  ip -6 route replace ''${!prefix_var}/''${!plen_var} via $QUERY6_REMOTE_ADDR dev $QUERY6_IFACE_NAME
                done
              }
              unknown_handler() {
                echo "Unhandled function call ''${*}"
                exit 123
              }
              case "$1" in
                "leases6_committed")
                  leases6_committed
                ;;
                *)
                  unknown_handler "''${@}"
                ;;
              esac
            '';
            sync = false;
          };
        };
        interfaces-config = {
          interfaces = singleton "eth1";
          service-sockets-max-retries = 10;
          service-sockets-retry-wait-time = 1000; # ms
          service-sockets-require-all = true;
        };
        lease-database.type = "memfile"; # persistence is irrelevant
        subnet6 = singleton {
          id = 1;
          interface = "eth1";
          subnet = "2001:db8:1100::/40";
          pd-pools = singleton {
            prefix = "2001:db8:1111::";
            prefix-len = 48;
            delegated-len = 56;
          };
        };
      };
    };
    specialisation.secondPrefixDelegation.configuration.services.kea.dhcp6.settings.subnet6 =
      mkForce
        (singleton {
          id = 1;
          interface = "eth1";
          subnet = "2001:db8:2a00::/40";
          pd-pools = singleton {
            prefix = "2001:db8:2a01::";
            prefix-len = 48;
            delegated-len = 56;
          };
        });
  };
}
