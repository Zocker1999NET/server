{ globalArg, others, ... }@interface:
let
  inherit (globalArg) config lib libBNet;
  ifCfg = interface.config;
  routCfg = ifCfg.routing;
  #
  inherit (builtins)
    attrNames
    concatMap
    elem
    filter
    groupBy
    length
    ;
  inherit (libBNet) types;
  inherit (lib.attrsets) filterAttrs genAttrs;
  inherit (lib.lists) singleton unique;
  inherit (lib.modules) mkMerge mkOrder;
  inherit (lib.trivial) pipe;
  optional = val: if val != null then singleton val else [ ];
  optEntry = val: lib.mkIf (val != null) (singleton val);
in
{

  imports = [
    # files
    ./ipv4Mode.nix
    ./ipv6Mode.nix
  ];

  options.routing = {

    # TODO (feature) separate IPv4 & IPv6 routing settings

    allowTo = lib.mkOption {
      description = ''
        List of interfaces to which packets from this one
        should be forwarded.

        This is if you want to manually define eventually required NAT rules.
        Otherwise, it is recommend to use:
        - {option}`.routing.upstream`
        - {option}`.routing.plain`
        - {option}`.routing.natted`
      '';
      type = with types; listOf ifName;
      default = [ ];
      example = [ "wan0" ];
    };

    plain = lib.mkOption {
      description = ''
        List of interfaces to which all traffic from this one
        can be forwarded transparently (i.e. without srcnat).

        This is e.g. useful to give VPN users access to local networks.
        Be aware that for that case to fully work,
        devices in the local networks should send reverse packets to this router,
        either because:
        - they match the default route to this router anyway
          (the default for local networks)
        - the router explicitly announces this route (not supported by module yet)
        - you apply srcnat on the reverse direction

        For that functionality, this list gets merged into {option}`.routing.allowTo`.
      '';
      type = with types; listOf ifName;
      default = [ ];
    };
    natted = lib.mkOption {
      description = ''
        List of interfaces to which all traffic from this one
        can be forwarded with srcnat for both ipv4 & ipv6.

        This is e.g. useful to provide users of a VPN with internet access.

        For that functionality, this list gets merged into {option}`.routing.allowTo`
        and into {option}`.srcnat.both.enableFor`.
      '';
      type = with types; listOf ifName;
      default = [ ];
    };

    # generalized options required for some modes

    ipv4Address = lib.mkOption {
      description = ''
        The IPv4 address used for the router on this interface.

        The CIDR automatically determines the DHCP pool,
        if not defined otherwise.
      '';
      type = with types; nullOr ipv4Network;
      default = null;
    };
    ipv6InterfaceId = lib.mkOption {
      description = ''
        The IPv6 interface id used for the router on this interface.

        If `null`, defaults to the EUI48 interface id.
      '';
      type = with types; nullOr ipv6IfId;
      default = null;
    };
    ipv6ULAPrefix = lib.mkOption {
      description = ''
        An IPv6 unique local address prefix to announce on LAN as well.

        If omitted, no ULA prefix is announced.
      '';
      type = with types; nullOr ipv6Network;
      default = null;
    };

    domain = lib.mkOption {
      description = "Domain announced via DHCPv4 / ICMPv6 (RA) / DHCPv6";
      type = types.str;
      default = config.networking.domain;
      defaultText = lib.literalExpression "config.networking.domain";
      example = "local";
    };

    upstream = lib.mkOption {
      description = ''
        The upstream interface of this one.

        ipv4Mode / ipv6Mode will define the relation with the upstream interface
        (e.g. if srcnat is required).
        Also, this setting is relevant for stuff like prefix delegation.
      '';
      type = with types; nullOr ifName;
      default = null;
      example = "wan0";
    };
    upstreamIdx = lib.mkOption {
      description = ''
        The index number this interface has
        in the context to its upstream interface.
        All downstream interfaces of a single upstream interface
        need to have a different index assigned.

        This index e.g. determines the used IPv6 prefix
        from a DHCPv6 prefix delegation.
      '';
      type =
        with types;
        oneOf [
          (enum [ "auto" ])
          (ints.between 0 16384) # arbitary maximum
        ];
      default = "auto";
      example = 1;
    };

    # inverse options
    allowedTo = lib.mkOption {
      internal = true;
      readOnly = true;
      default = filter (x: elem ifCfg.name x.routing.allowTo) others;
    };
    downstreams = lib.mkOption {
      internal = true;
      readOnly = true;
      default = filter (x: x.routing.upstream == ifCfg.name) others;
    };

  };

  config = {

    assertions = [
      (
        let
          duplicated = pipe routCfg [
            (c: [
              c.plain
              c.natted
              (singleton c.upstream)
            ])
            (concatMap unique)
            (groupBy (x: x))
            (filterAttrs (_: v: length v > 1))
            attrNames
          ];
        in
        {
          assertion = duplicated == [ ];
          message = "some interfaces are defined as upstream, plain & natted at the same time: ${toString duplicated}";
        }
      )
      # TODO check upstreamIdx is not already used by another interface (check only if required)
    ];

    # TODO split in ipv4 & ipv6
    dstnat.upstreams = optEntry routCfg.upstream;
    # TODO sensible order
    firewall.forwardToRules = mkMerge [
      (genAttrs routCfg.allowTo (
        _:
        mkMerge [
          ''ip6 nexthdr icmpv6 jump rfc4890-icmpv6-site-outbound comment "also blocks some ICMP types"''
          (mkOrder 2000 ''accept comment "for everything else"'')
        ]
      ))
      # as inbound interface, allow ICMPv6 traffic
      (genAttrs (map (x: x.name) routCfg.allowedTo) (
        _: "ip6 nexthdr icmpv6 jump rfc4890-icmpv6-site-inbound"
      ))
    ];
    routing.allowTo = unique (routCfg.plain ++ routCfg.natted ++ optional routCfg.upstream);
    srcnat.both.enableFor = unique routCfg.natted;

  };

}
