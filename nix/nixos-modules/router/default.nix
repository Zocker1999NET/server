{
  lib, # uses some of my library extensions
  outputs,
  ...
}@flakeArg:
{ config, options, ... }@globalArg:
let
  cfg = config.x-banananetwork.routerVM;
  nftMarks = config.networking.nftables.marks.values;
  # my lib
  inherit (builtins)
    attrValues
    concatMap
    concatStringsSep
    filter
    groupBy
    isInt
    mapAttrs
    ;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.modules) importsApplyMods;
  inherit (lib.trivial) flip pipe;
  # nft helpers
  escapeNftablesStr = arg: ''"${builtins.replaceStrings [ ''"'' ] [ ''\"'' ] (toString arg)}"'';
  nftComment = obj: lib.optionalString (obj != null) " comment ${escapeNftablesStr obj}";
  nftConcatComment =
    comment: list:
    let
      inherit (builtins) concatStringsSep length match;
      inherit (lib.lists) findFirstIndex sublist;
      strList = map (x: if isInt x then toString x else x) list;
      concat = concatStringsSep " . ";
      len = length strList;
      mapMiddle = findFirstIndex (s: match "[[:space:]]*:[[:space:]]*" s != null) null strList;
      left = sublist 0 mapMiddle strList;
      right = sublist (mapMiddle + 1) (len - mapMiddle) strList;
      commStr = nftComment (comment.comment or comment);
    in
    if mapMiddle == null then
      "${concat strList}${commStr}"
    else
      "${concat left}${commStr} : ${concat right}";
  nftConcat = nftConcatComment null;
  # useful to combine port rules
  mapAttrsJoin =
    sep: attrs: mapFun:
    assert builtins.isString sep;
    assert builtins.isAttrs attrs;
    assert builtins.isFunction mapFun;
    pipe attrs [
      (lib.attrsets.filterAttrs (
        _: v:
        !builtins.elem v [
          null
          ""
          [ ]
          { }
        ]
      ))
      (lib.attrsets.mapAttrsToList mapFun)
      (filter (x: x != null && x != ""))
      (concatStringsSep sep)
    ];
  mapListJoin =
    sep: list: mapFun:
    assert builtins.isString sep;
    assert builtins.isList list;
    assert builtins.isFunction mapFun;
    builtins.concatStringsSep sep (builtins.map mapFun list);
  filterMapJoin =
    sep: attr: mapFun:
    assert builtins.isString sep;
    assert builtins.isAttrs attr;
    assert builtins.isFunction mapFun;
    lib.trivial.pipe attr [
      attrValues
      (filter (x: x.enable))
      (map mapFun)
      (filter (x: x != null && x != ""))
      (concatStringsSep sep)
    ];
  ruleFromList =
    list: embedFun:
    pipe list [
      (builtins.concatStringsSep ", ")
      (x: lib.strings.conditionalString list (embedFun x))
    ];
  setElemList = flip ruleFromList (set: "elements = { ${set} }");
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
  hostnameType = lib.types.strMatching "^([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$" // {
    description = "hostname as per RFC";
  };
  nftablesReference = lib.types.strMatching "^@.+$" // {
    description = "nftables Set reference (starting with `@`)";
  };
  # assumption: these protocols need to support exactly 16-bit source & destination ports and place them at the beginning of their header (so "th sport" & "th dport" in nftables work correctly)
  protoList = [
    "dccp"
    "sctp"
    "tcp"
    "udp"
    "udplite"
  ];
  protoType = lib.types.enum protoList;
  # undefined for non-valid IP addresses
  getIpVersion = ip: if lib.strings.hasInfix ":" ip then "ipv6" else "ipv4";
  # TODO (feature) allow exposure of devices without static IPs
  # - by marking "dropped" packets during forwarding instead
  # - and then filtering them on postrouting using dest MAC
  # - disadvantage: enables use of all addresses (incl. privacy extensions)
  ifConfigs = pipe cfg.interfaces [
    attrValues
    (filter (x: x.enable))
  ];
in
{

  imports = importsApplyMods [
    # modules
    outputs.nixosModules.systemd-radv-fadeout
    # files
    ./references.nix
    # compatibility with third-party services
    ./tailscale.nix
  ];

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

      # TODO DNS entries for WAN & LAN side

      # TODO migrate to interfaces submodule
      /*
        lanEmitRejections = lib.mkEnableOption ''
          Whether to emit ICMP(v6) rejections to the trusted LAN
          if the router’s firewall blocks a package.

          Should make it easier to debug cases
          where the router blocks certain packages'';

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
      */

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

      interfaces = lib.mkOption {
        description = ''
          Describes interfaces on this router.
        '';
        type = lib.types.attrsOf (
          lib.types.submoduleWith {
            modules = [
              ./interfaces
              (
                { name, ... }:
                {
                  config._module.args = {
                    others = pipe cfg.interfaces [
                      (lib.filterAttrs (n: dev: n != name && dev.enable))
                      attrValues
                    ];
                  };
                }
              )
            ];
            specialArgs.globalArg =
              let
                extGlobalArg = globalArg // {
                  inherit cfg;
                  lib = lib // {
                    optionSets = import ./optionSets.nix extGlobalArg;
                    inherit
                      escapeNftablesStr
                      filterMapJoin
                      getIpVersion
                      hostnameType
                      mapAttrsJoin
                      mapListJoin
                      mkDisableOption
                      mkOutputOption
                      nftConcat
                      nftConcatComment
                      nftMarks
                      nftablesReference
                      protoList
                      protoType
                      ruleFromList
                      ;
                  };
                };
              in
              extGlobalArg;
          }
        );
        default = { };
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
        # TODO (upstream) add that hint to nixos docs in systemd.network.wait-online.anyInterface etc.
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

    systemd.network.links = pipe ifConfigs [
      (map (x: lib.attrsets.nameValuePair "10-${x.name}" { inherit (x) matchConfig linkConfig; }))
      builtins.listToAttrs
    ];
    systemd.network.networks = pipe ifConfigs [
      (map (x: lib.attrsets.nameValuePair "10-${x.name}" x.networkd))
      builtins.listToAttrs
    ];

    # firewall

    networking.firewall = {
      enable = true;
      checkReversePath = "strict";
      trustedInterfaces = map (x: x.name) ifConfigs; # managed by router chains
      filterForward = false; # replace with own chains
    };
    networking.nftables = {
      enable = true;
      marks.groups = {
        # protectWanSubnets = if cfg.protectWanSubnets then [ ] else null;
        snatShortcutted = [ ];
      };
      # TODO nftrace infrastructure for testing & debugging
      /*
        set trace-ipv4-proto {
          type ipv4_addr . ipv4_addr . inet_proto . inet_service;
          flags interval;
          elements = {
            0.0.0.0/0 . 0.0.0.0/0 . tcp . 80,
            0.0.0.0/0 . 0.0.0.0/0 . tcp . 8080
          }
        }
        set trace-ipv6-proto {
          type ipv6_addr . ipv6_addr . inet_proto . inet_service;
          flags interval;
          elements = {
            2000::/4 . 2000::/4 . tcp . 80,
            2000::/4 . 2000::/4 . tcp . 8080
          }
        }
        chain trace-packets {
          type filter hook prerouting priority -301; policy accept;
          ip saddr . ip daddr . ip protocol . th dport == @trace-ipv4-proto meta nftrace set 1
          ip6 saddr . ip6 daddr . ip6 nexthdr . th dport == @trace-ipv6-proto meta nftrace set 1
        }
      */
      /*
        chain drop-reject {
          ct state invalid drop comment "just drop early packets"
          icmp type destination-unreachable drop comment "avoid virtual loop"
          icmpv6 type destination-unreachable drop comment "avoid virtual loop"
          ${lib.optionalString cfg.lanEmitRejections ''
            #iifname ${lanName} ip saddr @${lanName}v4net reject comment "emit error to trusted net"
            #iifname ${lanName} ip6 saddr @${lanName}v6net reject comment "emit error to trusted net"
          ''}
          drop comment "drop anything else"
        }
      */
      # TODO (minor) assert that openFirewall / allowedTCP/UDPPorts does not collide with DNAT rules
      tables = {
        # append to OS table
        "nixos-fw".content = ''
          set same-if {
            type ifname . ifname;
            ${
              ruleFromList
                (map (
                  c:
                  nftConcat [
                    c.name
                    c.name
                  ]
                ) ifConfigs)
                (set: ''
                  elements = { ${set} }
                '')
            }
          }
          set ipv4-linklocal {
            type ipv4_addr;
            flags interval;
            elements = { 0.0.0.0/8, 169.254.0.0/16 }
          }
          set ipv6-linklocal {
            type ipv6_addr;
            flags interval;
            elements = { fe80::/10 }
          }
          chain global {
            ct state vmap {
              established : accept,
              related : accept,
              new : return,
              untracked : return,
              invalid : drop
            }
            drop comment "if a state is missing here"
          }
          # TODO export/upstream
          # these assume working connection state tracking
          chain rfc4890-icmpv6-site-common {
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
            } drop
            ip6 nexthdr icmpv6 drop
          }
          chain rfc4890-icmpv6-site-inbound-only {
            # in theory: allow pingable hosts (but not here)
            icmpv6 type time-exceeded icmpv6 code 1 accept comment "reassembly failed"
          }
          chain rfc4890-icmpv6-site-inbound {
            jump rfc4890-icmpv6-site-inbound-only
            jump rfc4890-icmpv6-site-common
          }
          chain rfc4890-icmpv6-site-outbound-only {
            icmpv6 type { echo-request, destination-unreachable, packet-too-big } accept;
            icmpv6 type time-exceeded icmpv6 code { 0, 1 } accept comment "transit/reassembly failed"
            icmpv6 type parameter-problem icmpv6 code { 1, 2 } accept comment "unknown header-type/option"
          }
          chain rfc4890-icmpv6-site-outbound {
            jump rfc4890-icmpv6-site-outbound-only
            jump rfc4890-icmpv6-site-common
          }
          ${filterMapJoin "\n" cfg.interfaces (ifCfg: ifCfg.nftables.content)}
          # grouped from interfaces together
          chain srcnat {
            type nat hook postrouting priority srcnat; policy accept;
            ${nftMarks.snatShortcutted.metaIsSet} masquerade persistent
            ip version 4 iifname . oifname @srcnat-ipv4 masquerade persistent
            ip6 version 6 iifname . oifname @srcnat-ipv6 masquerade persistent
          }
          set srcnat-ipv4 {
            type ifname . ifname;
            ${
              setElemList (flip concatMap ifConfigs (s: flip map s.srcnat.ipv4.enableFor (d: "${s.name} . ${d}")))
            }
          }
          set srcnat-ipv6 {
            type ifname . ifname;
            ${
              setElemList (flip concatMap ifConfigs (s: flip map s.srcnat.ipv6.enableFor (d: "${s.name} . ${d}")))
            }
          }
        '';
        /*
          "router-netdev" = lib.mkIf cfg.protectWanSubnets {
            family = "netdev";
            content = ''
              set wan_accepted {
                typeof ether daddr
                elements = { ${builtins.concatStringsSep ", " cfg.acceptableWanMACs} }
              }
              chain egress {
                ${nftMarks.protectWanSubnets.metaIsSet} ether daddr @wan_accepted accept
                ${nftMarks.protectWanSubnets.metaIsSet} drop
              }
            '';
          };
        */
      };
    };
    boot.blockedKernelModules = [
      "ip_tables"
      "iptable_nat"
    ];

    # prefix updater
    services.nft-update-addresses = {
      enable = true;
      settings = {
        nftTable = "nixos-fw";
        interfaces = pipe cfg.interfaces [
          attrValues
          (groupBy (x: x.name))
          (mapAttrs (
            _: x:
            assert builtins.length x == 1;
            (builtins.elemAt x 0).nft-update-addresses.config
          ))
        ];
      };
    };

    # DNS server
    # TODO (feature) migrate to blocky, seems way better & automated for our use case: https://0xerr0r.github.io/blocky/latest/
    # TODO (feature) exclude router from filtering itself (without config)
    # TODO (feature) add support for https://opennic.org/
    # TODO (upstream, minor) change NixOS upstream module to remove yaml-merge dependency if not required

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
