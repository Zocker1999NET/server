{ globalArg, others, ... }@interface:
let
  inherit (globalArg) lib libBNet;
  ifCfg = interface.config;
  srcCfg = ifCfg.firewall.sources;
  inherit (builtins)
    concatStringsSep
    groupBy
    isList
    isString
    ;
  inherit (lib) mapListJoin;
  inherit (libBNet) types;
  inherit (lib.attrsets) genAttrs;
  inherit (lib.lists) flatten;
  inherit (lib.strings) hasInfix;
  inherit (libBNet.strings) conditionalString;
  inherit (lib.trivial) flip pipe;
  groupSources = flip pipe [
    (groupBy (
      ip:
      if hasInfix "." ip then
        "ipv4"
      else if hasInfix ":" ip then
        "ipv6"
      else if hasInfix "v4" ip then
        "setv4"
      else if hasInfix "v6" ip then
        "setv6"
      else
        throw "cannot classify IP/set ${ip}"
    ))
    (
      grp:
      flip genAttrs (g: [ ]) [
        "ipv4"
        "ipv6"
        "setv4"
        "setv6"
      ]
      // grp
    )
  ];
  mapRules =
    sources:
    assert isList sources;
    rule:
    assert isString rule;
    let
      grouped = groupSources sources;
    in
    ''
      ${conditionalString grouped.ipv4 "ip saddr { ${concatStringsSep ", " grouped.ipv4} } ${rule}"}
      ${mapListJoin "\n" grouped.setv4 (n: "ip saddr ${n} ${rule}")}
      ${conditionalString grouped.ipv6 "ip6 saddr { ${concatStringsSep ", " grouped.ipv6} } ${rule}"}
      ${mapListJoin "\n" grouped.setv6 (n: "ip6 saddr ${n} ${rule}")}
    '';
  othersExpected = pipe others [
    (map (i: i.firewall.sources.nftExpected))
    flatten
  ];
in
{

  options.firewall.sources = {

    enable = lib.mkDisableOption "filtering packets for having valid source IP addresses";

    ignoreIncomingRoutes = lib.mkOption {
      description = ''
        Whether to deny routes & addresses incoming via DHCP or RA clients
        using sources expected to be used by other interfaces.

        Only statically assigned routes are passed.
        This may allow the DHCP or RA client to re-apply for a compatible address.

        Currently, this does only apply to the IPv6 RA client.
      '';
      default = true;
    };

    # TODO test
    expected = lib.mkOption {
      description = ''
        Packets incoming from this interface must use source IPs declared here.
        Will be merged with `.allowed`.

        If set to `null`, all IPs in the same subnet of the router IPs are allowed instead,
        which is useful when IP subnet is chosen dynamically, e.g. via DHCPv6 prefix delegation,
        or already defined otherwise).

        **Do NOT USE overlapping source IPs with this option!**
        if `blockOthersExpected` is enabled on the other interface overlapping,
        as this will lead into a DoS of that interface.
      '';
      type = with types; nullOr (listOf ipNetwork);
      default = null;
      example = [
        "10.0.0.0/8"
        "fc00::/7"
      ];
    };

    allowed = lib.mkOption {
      description = ''
        Packets incoming from this interface must use source IPs declared here.
        Will be merged with `.expected`.

        If set to `null`, all IPs in the same subnet of the router IPs are allowed instead,
        which is useful when IP subnet is chosen dynamically, e.g. via DHCPv6 prefix delegation,
        or already defined otherwise).
      '';
      type = with types; nullOr (listOf ipNetwork);
      default = null;
      example = [
        "10.0.0.0/8"
        "fc00::/7"
      ];
    };

    blockOthersExpected = lib.mkEnableOption ''
      blocking of incoming connections utilizting source IPs used on other interfaces
      (i.e. `expectedSourceIPs`, excluding `all`;
      this can lead into a DoS in case two interfaces use overlapping subnets)'';

    # === output
    nftExpected = lib.mkOutputOption {
      default =
        if srcCfg.expected == null then
          [
            "@${ifCfg.name}v4net"
            "@${ifCfg.name}v6net"
          ]
        else
          srcCfg.expected;
    };
    nftAllowed = lib.mkOutputOption {
      default =
        (
          if srcCfg.allowed == null then
            lib.optionals (srcCfg.expected != null) [
              "@${ifCfg.name}v4net"
              "@${ifCfg.name}v6net"
            ]
          else
            srcCfg.allowed
        )
        ++ srcCfg.nftExpected;
    };

  };

  config = lib.mkIf srcCfg.enable {
    nftables.chains.sourceCheck = ''
      type filter hook prerouting priority filter; policy drop;
      iifname != ${ifCfg.name} accept
      # TODO what about pkttype other ?
      meta pkttype { broadcast, multicast } accept comment "we cannot determine here if destination was chosen correctly"
      ip saddr 0.0.0.0/8 accept
      ${conditionalString srcCfg.blockOthersExpected (mapRules othersExpected "drop")}
      ${mapRules srcCfg.nftAllowed "accept"}
    '';
    networkd.ipv6AcceptRAConfig = lib.mkIf srcCfg.ignoreIncomingRoutes (
      let
        othersIPv6Routes = concatStringsSep " " (groupSources othersExpected).ipv6;
      in
      {
        PrefixDenyList = othersIPv6Routes;
        RouteDenyList = othersIPv6Routes;
      }
    );

  };

}
