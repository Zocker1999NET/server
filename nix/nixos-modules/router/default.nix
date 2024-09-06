{
  lib, # uses some of my library extensions
  ...
}@flakeArg:
{ config, ... }:
let
  cfg = config.x-banananetwork.routerVM;
  # TODO avert to options
  wanName = "wan0";
  lanName = "lan0";
  # my lib
  escapeNftablesStr =
    arg:
    let
      inherit (builtins) match replaceStrings;
      string = toString arg;
    in
    if match "[[:alnum:],._+:@%/-]+" string == null then
      ''"${replaceStrings [ ''"'' ] [ ''\"'' ] string}"''
    else
      string;
  filterAttrs =
    filtFun:
    assert builtins.isFunction filtFun;
    lib.filterAttrs (_: filtFun);
  filterMapAttrs =
    attr: filtFun: mapFun:
    assert builtins.isAttrs attr;
    assert builtins.isFunction filtFun;
    assert builtins.isFunction mapFun;
    builtins.mapAttrs (_: mapFun) (filterAttrs filtFun attr);
  filterMapAttrsToList =
    attr: filtFun: mapFun:
    assert builtins.isAttrs attr;
    assert builtins.isFunction filtFun;
    assert builtins.isFunction mapFun;
    lib.mapAttrsToList (_: mapFun) (filterAttrs filtFun attr);
  # useful to combine port rules
  mapListJoin =
    sep: list: mapFun:
    assert builtins.isString sep;
    assert builtins.isList list;
    assert builtins.isFunction mapFun;
    builtins.concatStringsSep sep (builtins.map mapFun list);
  filterMap =
    list: mapFun:
    assert builtins.isList list;
    assert builtins.isFunction mapFun;
    map mapFun (builtins.filter (x: x.enable) list);
  filterMapJoin =
    sep: attr: mapFun:
    assert builtins.isString sep;
    assert builtins.isAttrs attr;
    assert builtins.isFunction mapFun;
    lib.trivial.pipe mapFun [
      (filterMapAttrsToList attr (x: x.enable))
      (builtins.filter (x: x != null && x != ""))
      (builtins.concatStringsSep sep)
    ];
  mkDisableOption = arg: (lib.mkEnableOption arg) // { default = true; };
  # TODO think about to make it just readOnly, requiring defaultText
  mkOutputOption =
    arg:
    lib.mkOption (
      {
        internal = true;
        readOnly = true;
      }
      // arg
    );
  mkInterfaceOption =
    name:
    lib.mkOption {
      description = ''
        MAC address of device to be used as ${name} interface.

        Corresponds to the MACAdress= option in the [Match] section
        in {manpage}`systemd.network(5)` files.
      '';
      type = lib.types.eui48;
      example = "AA:BB:CC:DD:EE:FF";
    };
  whitespaceList = list: builtins.concatStringsSep " " list;
  hostnameType = lib.types.strMatching "^([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$" // {
    description = "hostname as per RFC";
  };
  formatMAC =
    let
      badChars = [
        "."
        ":"
        "_"
        "-"
      ];
      goodChars = map (x: "") badChars;
    in
    mac:
    lib.trivial.pipe mac [
      (builtins.replaceStrings badChars goodChars)
    ];
  protoList = [
    "dccp"
    "sctp"
    "tcp"
    "udp"
    "udplite"
  ];
  protoType = lib.types.enum protoList;
  # required for IPv4 as handled at built time
  dnatMapBuilder =
    proto: destMap: devices: embedFun:
    let
      devFilt = filterAttrs (dev: (destMap dev) != null) devices;
      protoMap = dev: (dev.nftUpdateAddressesConfig destMap).${proto}.forwarded;
      mapEntry =
        {
          wanPort,
          dest,
          lanPort,
        }:
        "${toString wanPort} : ${dest} . ${toString lanPort}";
      builtMap = dev: lib.concatMapStringsSep ", " mapEntry (protoMap dev);
      built = filterMapJoin ", " devFilt builtMap;
    in
    if built == "" then "" else embedFun built;
  # TODO allow exposure of devices without static IPs
  # - by marking "dropped" packets during forwarding instead
  # - and then filtering them on postrouting using dest MAC
  # - disadvantage: enables use of all addresses (incl. privacy extensions)
  deviceSubmodule =
    { name, ... }@device:
    let
      dev = device.config;
    in
    {
      options = {
        enable = lib.mkOption {
          description = "Configure rules for this device";
          type = lib.types.bool;
          default = true;
        };
        name = lib.mkOption {
          description = "hostname of the device";
          type = hostnameType;
          default = name;
        };
        description = lib.mkOption {
          description = "Descriptive, human-readable name for that device";
          type = lib.types.str;
          default = name;
        };
        mac = lib.mkOption {
          description = "MAC Address of device";
          type = lib.types.eui48;
        };
        staticIPv4 = lib.mkOption {
          description = "Static DHCPv4 lease address for device";
          type = with lib.types; nullOr ipv4AddressPlain;
          default = null;
        };
        fullyExposed = lib.mkEnableOption "to fully expose this device via IPv6, making other firewall rules except NATs irrelevant";
        forwardedExposed = mkDisableOption ''
          Whether to enable automatic exposure of port forwardings via IPv6.

          For example, if a port forwarding from 8080 to 80 is established,
          then the port 80 will also be exposed directly for the device’s IPv6,
          making using NAT optional'';
        # TODO really limit ICMP pings to IPv6 addresses (currently fully allowed)
        allowICMPEcho = lib.mkEnableOption "forwarding of ICMP echos via IPv6 to the device" // {
          default = device.config.exposedPorts != [ ];
          defaultText = lib.literalExpression '''';
        };
        exposedPorts = lib.mkOption {
          description = ''
            Ports which should be accessible to the public via IPv6.

            Adding one port does enable ICMP pings to that host.
          '';
          type = lib.types.attrsOf (
            lib.types.submodule (
              { name, ... }@exposed:
              let
                cfg = exposed.config;
                comment = "comment ${escapeNftablesStr cfg.comment}";
                accept = "accept ${comment}";
              in
              {
                options = {
                  enable = mkDisableOption "this port exposure rule";
                  comment = lib.mkOption {
                    description = ''
                      Comment for this port forwarding rule.

                      Will be added to nftables rules.
                    '';
                    default = "${device.name} - ${name}";
                    defaultText = lib.literalExpression ''''${device.name} - ''${name}'';
                  };
                  port = lib.mkOption {
                    description = "port";
                    type = lib.types.port;
                  };
                  protocol = lib.mkOption {
                    description = "Protocol for which the port forwarding will be established";
                    type = protoType;
                    default = "tcp";
                  };
                  nftablesForwardingRules = lib.mkOption {
                    internal = true;
                    default = ''
                      ip6 daddr ${dev.nftablesIPv6Dest} ${cfg.protocol} dport ${toString cfg.port} ${accept}
                    '';
                  };
                };
              }
            )
          );
          default = { };
        };
        forwardedPorts = lib.mkOption {
          description = ''
            Ports which should be forwarded from the router WAN IPv4 & v6 address to this device.

            The port is then made accessible using DNAT
            on all packets sent to the router’s public interface
            via IPv4 (if `config`{staticIPv4}` is set) and IPv6.
          '';
          type = lib.types.attrsOf (
            lib.types.submodule (
              { name, ... }@forwarded:
              let
                cfg = forwarded.config;
                comment = "comment ${escapeNftablesStr cfg.comment}";
                accept = "accept ${comment}";
                l4Rule = "${cfg.protocol} dport ${toString cfg.lanPort} ${accept}";
                l4WanRule = "${cfg.protocol} dport ${toString cfg.wanPort}";
              in
              {
                options = {
                  enable = mkDisableOption "this port forwarding rule";
                  comment = lib.mkOption {
                    description = ''
                      Comment for this port forwarding rule.

                      Will be added to nftables rules.
                    '';
                    default = "${device.name} - ${name}";
                    defaultText = lib.literalExpression ''''${device.name} - ''${name}'';
                  };
                  protocol = lib.mkOption {
                    description = "Protocol for which the port forwarding will be established.";
                    type = protoType;
                    default = "tcp";
                  };
                  wanPort = lib.mkOption {
                    description = "port on the WAN side";
                    type = lib.types.port;
                    default = cfg.lanPort;
                    defaultText = lib.literalExpression "cfg.lanPort";
                  };
                  lanPort = lib.mkOption {
                    description = "port on the LAN / client side";
                    type = lib.types.port;
                  };
                  expose = lib.mkOption {
                    description = "Enables exposure of {option}`lanPort` directly via IPv6";
                    type = lib.types.bool;
                    default = device.config.forwardedExposed;
                    defaultText = lib.literalExpression "cfg.forwardedExposed";
                  };
                  nftablesForwardingRules = mkOutputOption {
                    default = ''
                      ${lib.optionalString (dev.staticIPv4 != null) "ip daddr ${dev.staticIPv4} ${l4Rule}"}
                      ip6 daddr ${dev.nftablesIPv6Dest} ${l4Rule}
                    '';
                  };
                  nftablesPreroutingRules = mkOutputOption {
                    default = ''
                      ${lib.optionalString (
                        dev.nftablesIPv4Dest != null
                      ) "${l4WanRule} dnat ip to ${dev.nftablesIPv4Dest}:${toString cfg.lanPort} ${comment}"}
                    '';
                  };
                };
              }
            )
          );
          default = { };
          example = {
            http = {
              wanPort = 8080;
              lanPort = 80;
            };
            quic = {
              wanPort = 8443;
              lanPort = 443;
              protocol = "udp";
            };
          };
        };
        nftablesIPv4Dest = mkOutputOption { default = dev.staticIPv4; };
        nftablesIPv6Dest = mkOutputOption { default = ''@${lanName}v6_${formatMAC dev.mac}''; };
        nftUpdateAddressesConfig = mkOutputOption {
          default =
            destMap:
            let
              inherit (builtins) attrValues groupBy;
              inherit (lib.attrsets) genAttrs;
              groupByProto = attrs: groupBy (x: x.protocol) (attrValues attrs);
              exposed = groupByProto dev.exposedPorts;
              forwarded = groupByProto dev.forwardedPorts;
            in
            genAttrs protoList (proto: {
              exposed = filterMap (exposed.${proto} or [ ]) (exp: {
                inherit (exp) port;
                dest = destMap dev;
              });
              forwarded = filterMap (forwarded.${proto} or [ ]) (fw: {
                inherit (fw) wanPort lanPort;
                dest = destMap dev;
              });
            });
        };
        nftablesForwardingRules = mkOutputOption {
          default =
            if dev.fullyExposed then
              ''
                ip6 daddr ${dev.nftablesIPv6Dest} accept comment ${escapeNftablesStr "${dev.description} full exposure"}
              ''
            else
              ''
                ${filterMapJoin "\n" dev.exposedPorts (ep: ep.nftablesForwardingRules)}
                ${filterMapJoin "\n" dev.forwardedPorts (fw: fw.nftablesForwardingRules)}
                ip daddr ${dev.nftablesIPv4Dest} jump drop-reject
                ip6 daddr ${dev.nftablesIPv6Dest} jump drop-reject
              '';
        };
        nftablesPreroutingRules = mkOutputOption {
          default = filterMapJoin "\n" dev.forwardedPorts (fw: fw.nftablesPreroutingRules);
        };
      };
      config = {
        exposedPorts = filterMapAttrs dev.forwardedPorts (fw: fw.enable && fw.expose) (fw: {
          comment = "${fw.comment} (exposed port forwarding)";
          port = fw.lanPort;
          inherit (fw) protocol;
        });
      };
    };
  # automatically assign mark integers for these reasons (if enabled)
  nftMarksDeclared = {
    inherit (cfg) protectWanSubnets;
    "${wanName}_snatShortcutted" = true;
  };
  nftMarks = lib.trivial.pipe nftMarksDeclared [
    lib.attrsToList
    (builtins.filter (x: x.value))
    (lib.imap1 (
      i: m: {
        inherit (m) name;
        value = toString i; # because will mostly be used in nftables rules
      }
    ))
    builtins.listToAttrs
  ];
in
{

  options = {
    boot.loader.systemd-boot.bootCounting.enable = lib.mkOption {
      description = ''
        to already pin option which will be coming in the future
        see https://nixos.org/manual/nixos/unstable/#sec-automatic-boot-assessment
      '';
      visible = false;
      type = lib.types.bool;
    };

    x-banananetwork.routerVM = {

      enable = lib.mkEnableOption "router functionality. This is intended to be disabled by a specialisation for recovery reasons";

      wanMAC = mkInterfaceOption "WAN";

      lanMAC = mkInterfaceOption "VM LAN";
      lanDomain = lib.mkOption {
        description = "domain advertised via DHCP / RA / DHCPv6";
        type = lib.types.str;
        default = config.networking.domain;
        defaultText = lib.literalExpression "config.networking.domain";
      };
      lanIPv4Address = lib.mkOption {
        description = ''
          The IPv4 address used for the router &
          its subnet used for addresses of clients.
        '';
        type = lib.types.str;
      };
      lanIPv6ULAPrefix = lib.mkOption {
        description = ''
          An IPv6 unique local address prefix to announce on LAN as well.
        '';
        type = lib.types.str;
      };

      trustableIPv6Prefixes = lib.mkOption {
        description = ''
          A list of IPv6 prefixes which should be trustable.

          In general, this means following features should be locked to trustable links only:
          - announced routes to these prefixes
          - TODO packets from/to these prefixes to/from links
        '';
        type = with lib.types; listOf str;
        default = [ ];
      };

      # TODO DNS entries for WAN & LAN side
      lanDevices = lib.mkOption {
        description = ''
          Describes properties for a LAN device
          (e.g. DHCP static leases & port forwardings).

          For IPv6 based rules to work,
          devices must use their stable EUI64 IPv6 address
          for the prefix announced via SLAAC.
          You can recognise those as they reflect the MAC address of the interface.

          The router cannot forward ports for devices only using
          private IPv6 addresses according to
          RFC 4941 (IPv6 privacy extensions)
          or RFC 7217 (stable private IPv6 addresses).
        '';
        type = lib.types.attrsOf (lib.types.submodule deviceSubmodule);
        default = { };
      };

      lanEmitRejections = lib.mkEnableOption ''
        Whether to emit ICMP(v6) rejections to the trusted LAN
        if the router’s firewall blocks a package.

        Should make it easier to debug cases
        where the router blocks certain packages'';

      # TODO test
      protectWanSubnets = lib.mkEnableOption ''
        firewall rules *trying* to protect the WANs local subnets.

        Despite best efforts, I cannot make any gurantees
        that this can prevent all attempts from LAN devices accessing WAN devices,
        especially because of possible, additional IPv6 subnets.'';
      acceptableWanMACs = lib.mkOption {
        description = ''
          When {option}`x-banananetwork.routerVM.protectWanSubnets` is enabled,
          this provides a list of devices which should still be accessible.

          If you want your LAN to have connection to the Internet,
          this list MUST include your gateway’s MAC address.
        '';
        type = lib.types.listOf lib.types.eui48;
        default = [ ];
        example = [ "AA:BB:CC:DD:EE:FF" ];
      };

      dns = {
        upstreams = lib.mkOption {
          description = "List of DNS servers used by DNS server for clients.";
          type = lib.types.listOf lib.types.str;
        };
        fallbacks = lib.mkOption {
          description = "List of DNS servers used as fallbacks (i.e. when all upstreams are unreachable). Used by DNS server for clients.";
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
        bootstraps = lib.mkOption {
          description = "List of DNS servers used to bootstrap list of other DNS servers. Used by DNS server for clients.";
          type = lib.types.listOf lib.types.str;
          default = cfg.dns.localFallbacks;
          defaultText = lib.literalExpression "config.x-banananetwork.routerVM.dns.localFallbacks";
        };
        localFallbacks = lib.mkOption {
          description = "List of DNS servers used as local fallbacks, i.e. added aside of own DNS server to {file}`/etc/resolv.conf` of router itself.";
          type = with lib.types; listOf ipAddress;
          default = [ ];
        };
        webui.username = lib.mkOption {
          description = "Username for AdGuard Home admin account.";
          type = lib.types.str;
        };
        webui.password = lib.mkOption {
          description = ''
            Hash for AdGuard Home admin account.
            Can be created with .e.g. {command}`mkpasswd --method=bcrypt`'

            For more info, read in the [Adguard Home Wiki](https://github.com/AdguardTeam/AdguardHome/wiki/Configuration#reset-web-password)
          '';
          type = lib.types.str;
        };
        filterlists = lib.mkOption {
          description = "List of URLs of filterlists which entries should be blocked";
          type = with lib.types; listOf str;
          default = [ ];
        };
      };

    };
  };

  # TODO configure NAT64 with 464XLAT
  #   requires: https://github.com/systemd/systemd/issues/23674
  #   or services.clat.enable = true; & test how it works

  # IPv6 prefix delegation config inspired by: https://major.io/p/dhcpv6-prefix-delegation-with-systemd-networkd/

  config = lib.mkIf cfg.enable {

    warnings = lib.singleton (
      lib.mkIf (lib.versionAtLeast lib.version "24.11") "remove manual sysctl for ip forwarding, as can be replaced by systemd-networkd settings"
    );

    # I will pin a lot of stuff, to ensure future changes on NixOS are noticed
    networking = {
      enableIPv6 = true; # also just a statement
      nameservers = [
        # localhost
        "::1"
        "127.0.0.1"
      ] ++ cfg.dns.localFallbacks;
      tempAddresses = "disabled"; # do not manage that here
      useDHCP = false; # do not intervene with router config
      useNetworkd = true;
    };
    services.resolved.enable = false; # invoked by systemd.network

    # general
    systemd.network = {
      enable = true;
      config.networkConfig = lib.mkIf (lib.versionAtLeast lib.version "24.11") {
        # these options are introduced with systemd 256 -> NixOS 24.11
        IPv4Forwarding = true;
        IPv6Forwarding = true;
        UseDomains = false;
      };
      wait-online = {
        anyInterface = false; # all which are listed as required
        enable = true;
        # more is configured per netdev/network as RequiredForOnline
        # TODO add that hint to nixos docs in systemd.network.wait-online.anyInterface etc.
      };
    };
    boot.kernel.sysctl = lib.mkIf (!lib.versionAtLeast lib.version "24.11") {
      "net.ipv4.conf.default.forwarding" = true;
      "net.ipv4.conf.all.forwarding" = true;
      "net.ipv6.conf.default.forwarding" = true;
      "net.ipv6.conf.all.forwarding" = true;
    };
    # expose for easier debugging
    environment.systemPackages = lib.singleton config.services.nft-update-addresses.package;

    # following settings are ordered according to the respective man pages

    # configure "real" devices
    systemd.network.links =
      let
        # defaults
        linkConfig = {
          MACAddressPolicy = "persistent";
          NamePolicy = ""; # -> use Name=
          AlternativeNamesPolicy = "mac slot path onboard";
          AutoNegotiation = true;
        };
      in
      {
        # auto-generated files are using numbers "70" & higher
        "10-${wanName}" = {
          matchConfig.PermanentMACAddress = cfg.wanMAC;
          linkConfig = linkConfig // {
            Name = wanName;
            Description = "WAN device";
          };
        };
        "10-${lanName}" = {
          matchConfig.PermanentMACAddress = cfg.lanMAC;
          linkConfig = linkConfig // {
            Name = lanName;
            Description = "LAN device";
          };
        };
      };

    # virtual devices
    systemd.network.netdevs = { };

    # networks
    systemd.network.networks = {
      "10-${wanName}" = {
        matchConfig.Name = wanName;
        linkConfig = {
          RequiredForOnline = "degraded"; # = has addresses assigned
          RequiredFamilyForOnline = "any";
        };
        networkConfig = {
          DHCP = "yes"; # both IPv4 & IPv6 (prefix delegation)
          LinkLocalAddressing = "ipv6";
          IPv6LinkLocalAddressGenerationMode = "eui64";
          LLMNR = false;
          MulticastDNS = false;
          LLDP = "routers-only";
          DNSDefaultRoute = true;
          IPv6AcceptRA = true;
        };
        dhcpV6Config = {
          PrefixDelegationHint = "::/60"; # TODO make configurable
        };
        ipv6AcceptRAConfig = {
          PrefixDenyList = whitespaceList cfg.trustableIPv6Prefixes;
          RouteDenyList = whitespaceList cfg.trustableIPv6Prefixes;
        };
      };
      "10-${lanName}" = {
        matchConfig.Name = lanName;
        linkConfig = {
          RequiredForOnline = false;
        };
        networkConfig = {
          DHCPServer = true;
          LinkLocalAddressing = "ipv6";
          IPv6LinkLocalAddressGenerationMode = "eui64";
          LLMNR = true;
          MulticastDNS = true;
          LLDP = "routers-only";
          EmitLLDP = true;
          IPv6AcceptRA = false;
          IPv4ReversePathFilter = "strict";
          IPv6SendRA = true;
          DHCPPrefixDelegation = true;
        };
        address = lib.singleton "fe80::1/64"; # also link-local router
        dhcpPrefixDelegationConfig = {
          UplinkInterface = "${wanName}";
          SubnetId = "0x0";
          Announce = true;
          Assign = true;
          Token = "static:::1";
          ManageTemporaryAddress = false;
        };
        dhcpServerConfig = {
          ServerAddress = cfg.lanIPv4Address;
          # pool automatically set from CIDR
          UplinkInterface = ":none";
          DNS = "_server_address";
          # TODO emit domain ipv4 as well
          SendOption = lib.singleton "15:string:${cfg.lanDomain}";
          EmitNTP = false; # IPv6 ftw.
          EmitSIP = false;
          EmitPOP3 = false;
          EmitSMTP = false;
          EmitLPR = false;
        };
        dhcpServerStaticLeases =
          filterMapAttrsToList cfg.lanDevices (dev: dev.enable && dev.staticIPv4 != null)
            (dev: {
              dhcpServerStaticLeaseConfig = {
                MACAddress = dev.mac;
                Address = dev.staticIPv4;
              };
            });
        ipv6SendRAConfig = {
          # TODO until https://github.com/systemd/systemd/issues/29651 is fixed:
          RouterLifetimeSec = lib.mkDefault (5 * 60); # set so low in case of a prefix renewal
          UplinkInterface = ":none";
          DNS = "_link_local";
          Domains = whitespaceList (lib.singleton cfg.lanDomain);
        };
        ipv6Prefixes = lib.singleton {
          ipv6PrefixConfig = {
            Prefix = cfg.lanIPv6ULAPrefix;
            Assign = true;
            Token = "static:::1";
          };
        };
      };
    };

    # firewall

    networking.firewall = {
      enable = true;
      checkReversePath = "strict";
      filterForward = false; # replace with own chains
      extraInputRules = ''
        jump router-inbound
      '';
    };
    networking.nftables = {
      enable = true;
      # TODO assert that openFirewall / allowedTCP/UDPPorts does not collide with DNAT rules
      tables = {
        # append to OS table
        "nixos-fw".content = ''
          set v6ula {
            type ipv6_addr
            flags interval
            elements = { fc00::/7 }
          }
          ${mapListJoin "\n" protoList (proto: ''
            map ${lanName}v4dnat${proto} {
              type inet_service : ipv4_addr . inet_service
              ${
                dnatMapBuilder proto (dev: dev.staticIPv4) cfg.lanDevices (built: ''
                  elements = { ${built} }
                '')
              }
            }
          '')}
          chain drop-reject {
            ct state invalid drop comment "just drop early packages"
            icmp type destination-unreachable drop comment "avoid virtual loop"
            icmpv6 type destination-unreachable drop comment "avoid virtual loop"
            ${lib.optionalString cfg.lanEmitRejections ''
              iifname ${lanName} ip saddr ${lanName}v4net reject comment "emit error to trusted net"
            ''}
            drop comment "drop anything else"
          }
          chain global {
            ct state established,related accept
            ct state invalid jump drop-reject
            ct state != { new, untracked } jump drop-reject
          }
          # TODO export/upstream
          # these assume working connection state tracking
          chain rfc4890-icmpv6-site-both {
            # TODO required? icmpv6 type echo-reply accept "already established"
            ip6 daddr fe80::/10 ip6 nexthdr icmpv6 drop comment "do not route link-local stuff, just in case"
            ip6 daddr ff00::/8 icmpv6 type echo-reply drop comment "drop ping responses to multicast"
            icmpv6 type parameter-problem icmpv6 code 0 accept comment "bad header"
            icmpv6 type {
              mld-listener-query,
              mld-listener-report,
              mld-listener-done,
              mld-listener-reduction,
              nd-router-solicit,
              nd-router-advert,
              nd-neighbor-solicit,
              nd-neighbor-advert,
              nd-redirect,
              router-renumbering,
              139, 140, # node information queries / replies
            } jump drop-reject
            ip6 nexthdr icmpv6 jump drop-reject
          }
          chain rfc4890-icmpv6-site-inbound {
            # TODO allow pingable hosts (but not here)
            icmpv6 type time-exceeded icmpv6 code 1 accept comment "reassembly failed"
            jump rfc4890-icmpv6-site-both
          }
          chain rfc4890-icmpv6-site-outbound {
            icmpv6 type { echo-request, destination-unreachable, packet-too-big } accept;
            icmpv6 type time-exceeded icmpv6 code { 0, 1 } accept comment "transit/reassembly failed"
            icmpv6 type parameter-problem icmpv6 code { 1, 2 } accept comment "unknown header-type/option"
            jump rfc4890-icmpv6-site-both
          }
          chain router-inbound {
            # stuff with .openFirewall is already accepted
            # to global just in case
            jump global
            iifname ${wanName} jump ${wanName}-inbound
            iifname ${lanName} jump ${lanName}-inbound
          }
          chain ${wanName}-inbound {
            ip6 daddr @${lanName}v6net jump drop-reject comment "drop requests from outbound to router"
          }
          chain ${lanName}-inbound {
            ip version 4 udp sport 68 udp dport 67 accept comment "DHCPv4"
            icmpv6 type nd-router-solicit accept comment "IPv6 SLAAC"
            udp dport 53 accept comment "DNS"
            tcp dport 53 accept comment "DNS"
          }
          chain router-forward {
            type filter hook forward priority filter; policy drop;
            jump global
            ct status dnat accept
            iifname ${lanName} oifname ${wanName} jump ${lanName}-to-${wanName}
            iifname ${wanName} oifname ${lanName} jump ${wanName}-to-${lanName}
            jump drop-reject
          }
          chain ${wanName}-to-${lanName} {
            jump rfc4890-icmpv6-site-inbound
            ${filterMapJoin "\n" cfg.lanDevices (dev: dev.nftablesForwardingRules)}
          }
          chain ${lanName}-to-${wanName} {
            jump rfc4890-icmpv6-site-outbound
            ${lib.optionalString cfg.protectWanSubnets ''
              # TODO try with & without mark
              #meta mark set ${nftMarks.protectWanSubnets} comment "protect WAN subnets"
              ip daddr @${wanName}v6net reject comment "protect ${wanName} subnet"
              ip6 daddr @${wanName}v6net reject comment "protect ${wanName} subnet"
            ''}
            ip6 saddr @v6ula reject comment "no general outbound with unique link locals"
            ip6 daddr @v6ula reject comment "no general outbound to unique link locals"
            ip saddr @${lanName}v4net accept comment "outbound allowed"
            ip6 saddr @${lanName}v6net accept comment "outbound allowed"
          }
          chain router-prerouting {
            type nat hook prerouting priority -100; policy accept;
            ${
              mapListJoin "\n" protoList (proto: ''
                iifname != ${wanName} ip daddr @${wanName}v4addr meta mark set ${
                  nftMarks."${wanName}_snatShortcutted"
                }
                iifname != ${wanName} ip6 daddr @${wanName}v6addr meta mark set ${
                  nftMarks."${wanName}_snatShortcutted"
                }
                ip daddr @${wanName}v4addr dnat ip to ${proto} dport map @${lanName}v4dnat${proto}
                ip6 daddr @${wanName}v6addr dnat ip6 to ${proto} dport map @${lanName}v6dnat${proto}
              '')
            }
          }
          chain router-postrouting {
            type nat hook postrouting priority 100; policy accept;
            iifname ${lanName} oifname ${wanName} ip version 4 masquerade comment "persistent not required as only one source addr available, avoid randonmness"
            meta mark ${nftMarks."${wanName}_snatShortcutted"} masquerade
          }
        '';
        "router-netdev" = lib.mkIf cfg.protectWanSubnets {
          family = "netdev";
          content = ''
            set wan_accepted {
              typeof ether daddr
              elements = { ${builtins.concatStringsSep ", " cfg.acceptableWanMACs} }
            }
            chain egress {
              meta mark ${nftMarks.protectWanSubnets} ether daddr @wan_accepted accept
              meta mark ${nftMarks.protectWanSubnets} jump drop-reject
            }
          '';
        };
      };
    };
    boot.blockedKernelModules = [
      "ip_tables"
      "iptable_nat"
    ];

    # prefix updater
    services.nft-update-addresses = {
      enable = true;
      settings =
        let
          inherit (builtins) attrValues;
          inherit (lib.attrsets) genAttrs;
          inherit (lib.lists) flatten;
          flatMap = mapFun: list: flatten (map mapFun list);
          destMap = dev: dev.mac;
          portMap = proto: dev: (dev.nftUpdateAddressesConfig destMap).${proto};
          combinePortCfg = devCfgs: {
            exposed = flatMap (devCfg: devCfg.exposed) devCfgs;
            forwarded = flatMap (devCfg: devCfg.forwarded) devCfgs;
          };
          combinePerProto =
            devices: proto:
            lib.trivial.pipe proto [
              portMap
              (filterMap (attrValues devices))
              combinePortCfg
            ];
          protoPortCfg = devices: genAttrs protoList (combinePerProto devices);
        in
        {
          nftTable = "nixos-fw";
          interfaces = {
            ${wanName} = { };
            ${lanName}.ports = protoPortCfg cfg.lanDevices;
          };
        };
    };

    # DNS server
    # TODO exclude router from filtering itself (without config)
    # TODO add support for https://opennic.org/
    # TODO change NixOS upstream module to remove yaml-merge dependency if not required

    services.adguardhome = {
      enable = true;
      allowDHCP = false;
      mutableSettings = false;
      port = 3000;
      settings = {
        http = {
          session_ttl = "5:00";
        };
        users = lib.singleton {
          name = "admin";
          password = ""; # TODO bcrypt htpasswd random stuff
        };
        auth_attempts = 5;
        block_auth_min = 5;
        dns = {
          port = 53;
          anonymize_client_ip = false;
          ratelimit = 100; # queries / second
          ratelimit_subnet_len_ipv4 = 32;
          ratelimit_subnet_len_ipv6 = 128;
          refuse_any = true;
          upstream_dns = cfg.dns.upstreams;
          fallback_dns = cfg.dns.fallbacks;
          bootstrap_dns = cfg.dns.bootstraps;
          local_ptr_upstreams = [
            # TODO
          ];
          upstream_mode = "load_balance";
          upstream_timeout = "10s";
          use_http3_upstream = true;
          enable_dnssec = true;
          cache_time = 36000;
          resolve_clients = true;
          serve_plain_dns = true;
          hostsfile_enabled = false;
        };
        filtering = {
          protection_enabled = true;
          filtering_enabled = true;
          blocking_mode = "nxdomain";
          blocked_response_ttl = 60; # seconds
          safe_search.enabled = false;
          safebrowsing_enabled = true;
        };
        querylog = {
          enabled = true;
          file_enabled = true;
          interval = "${toString (2 * 24)}h";
        };
        statistics = {
          enabled = true;
          interval = "${toString (7 * 24)}h";
        };
        filters = lib.trivial.flip map cfg.dns.filterlists (url: {
          enabled = true;
          inherit url;
          name = url;
          ID = builtins.hashString "sha1" url;
        });
        dhcp.enabled = false;
        tls.enabled = false;
        log.file = "syslog"; # journal
      };
    };

    # fallback specialisation for trivial network access

    specialisation.trivialNetwork.configuration = {
      x-banananetwork.routerVM.enable = lib.mkForce false;
      networking = {
        # DHCP on all interfaces
        useDHCP = lib.mkForce true;
        useNetworkd = lib.mkForce true;
      };
    };
    # order of specialisation v. older generation not clear
    # and no plan which order is senseful, for now
    boot.loader.systemd-boot.bootCounting.enable = false;

  };

}
