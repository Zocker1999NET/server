{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.modules) mkDefault;
  kindOpts = {

    "custom" = { };

    "wan-rfc7084" = {
      assertions = lib.singleton {
        assertion = ifCfg.devices == [ ];
        message = "configuring specific devices on a WAN interface does not make sense";
      };
      firewall = {
        sources = {
          allowed = [
            "0.0.0.0/0"
            "::/0"
          ];
          blockOthersExpected = true;
        };
      };
      networkd = mkDefault {
        linkConfig = {
          RequiredForOnline = "degraded"; # = has addresses assigned
          RequiredFamilyForOnline = "any";
        };
        networkConfig = {
          DHCP = "yes"; # both IPv4 & IPv6 (prefix delegation)
          LLMNR = false;
          MulticastDNS = false;
          LLDP = "routers-only";
          DNSDefaultRoute = true;
          IPv6AcceptRA = true;
        };
        dhcpConfig = {
          UseDNS = false; # we have our own
          UseSIP = lib.mkDefault false;
          #UseCaptivePortal = false; # no manual work on router anyway
          UseHostname = false; # we have our hostname
          UseDomains = false; # we have our domains
        };
        dhcpV6Config = {
          UseDNS = false; # we have our own
          #UseCaptivePortal = false; # no manual work on router anyway
          UseHostname = false; # we have our hostname
          UseDomains = false; # we have our domains
        };
        ipv6AcceptRAConfig = {

        };
      };
      # TODO
    };

    "lan-rfc7084" = {
      assertions = [
        {
          assertion = ifCfg.routing.downstreams == [ ];
          message = "a LAN interface should not have any downstream interfaces, but: ${
            toString (map (x: x.name) ifCfg.routing.downstreams)
          }";
        }
      ];
      firewall = {
        # TODO add rules conditionally
        inputRules = ''
          ip version 4 udp sport 68 udp dport 67 accept comment "DHCPv4"
          icmpv6 type nd-router-solicit accept comment "IPv6 SLAAC"
          udp dport 53 accept comment "DNS"
          tcp dport 53 accept comment "DNS"
        '';
      };
      networkd = {
        networkConfig = {
          LLMNR = true;
          MulticastDNS = true;
          LLDP = "routers-only";
          EmitLLDP = true;
        };
      };
      routing = {
        ipv4Mode = "nat+dhcp";
        ipv6Mode = mkDefault "dhcp-pd";
      };
      # TODO
    };

  };
in
{
  options = {
    kind = lib.mkOption {
      description = ''
        Logical type of this interface (i.e. for what is it used).

        Depending on the kind, the interface will automatically configured with sane defaults & assertions,
        making configuring a router easier & less error prone.
        E.g. with `wan` `sources.allowed = "all"`.
      '';
      type = lib.types.enum (builtins.attrNames kindOpts);
      default = "custom";
      example = "wan";
    };
  };
  config = lib.mkMerge (mapAttrsToList (kind: opts: lib.mkIf (ifCfg.kind == kind) opts) kindOpts);
}
