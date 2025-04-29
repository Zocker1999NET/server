{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  inherit (builtins) mapAttrs;
  ifCfg = interface.config;
  fwCfg = ifCfg.firewall;
  fwOpts = interface.options.firewall;
  inherit (lib) escapeNftablesStr;
  inherit (lib.modules) mkIf mkOrder;
  mkRulesOption =
    {
      description,
      notes ? "",
      ...
    }@args:
    lib.mkOption (
      removeAttrs args [
        "description"
        "notes"
      ]
      // {
        description = ''
          nftables rules for ${description}.

          ${notes}

          Useful notes for all firewall rules options here:
          - They are intended as "accept lists" (i.e. accept on any matching).
            Adding drop verdicts here may lead to unexpected behavior!
            (If you want to add absolute drop conditions,
            add new chains like the `blackhole` module does.)
          - Packets from established connections are allowed before via conntrack.
            (To ignore that, build a new chain.)
          - The nftables policy is set to `drop`.
            Still some rulesets accept all by default,
            so be aware of their NixOS option default value.
          - They cannot overrule negative mechanisms from this router implementation
            like `blackhole`, `input` or `sources`.
          - You can access the dynamic IPs from other interfaces via @<ifname>v<4|6>net or the router’s address with the suffix addr.
        '';
        type = lib.types.lines // {
          description = "nftables rules (concatenated with '\n')";
        };
        default = args.default or "";
      }
    );
  mapRules = mapAttrs (
    name: preamble:
    let
      ruleset = fwCfg."${name}Rules";
      opt = fwOpts."${name}Rules";
    in
    # only define chains if required
    # workaround with highestPrio required because chains are allowed to depend on other chains, making evaluation of the value before the submodule impossible
    mkIf (opt.highestPrio < 1500 || ruleset != "accept") { content = "${preamble}\n${ruleset}"; }
  );
in
{

  imports = [
    # files
    #./blackhole.nix # TODO add & test
    ./exposed.nix
    ./exposedPingable.nix
    ./forwardFrom.nix
    ./forwardTo.nix
    ./input.nix
    ./pingable.nix
    ./sources.nix
    ./system.nix
  ];

  options.firewall = {
    ingressRules = mkRulesOption {
      description = "all connections incoming from this interface (i.e. `iifname \${cfg.name}`)";
      notes = ''
        As of now, this ruleset is not expanded by other router submodules.
      '';
      default = "accept";
    };
    inputRules = mkRulesOption {
      description = "connections incoming from this interface to the router host (i.e. `iifname \${cfg.name}`)";
      notes = ''
        Other router submodules may already append their own rules to this ruleset,
        e.g. for allowing conntracked, DHCP, ICMPv6 & DNS traffic.
      '';
    };
    forwardRules = mkRulesOption {
      description = "connections incoming from this interface to other interfaces (i.e. `iifname \${cfg.name}`)";
      notes = ''
        Other router submodules may already append their own rules to this ruleset,
        e.g. for allowing conntracked, DNAT-forwarded or exposed devices/ports traffic.
      '';
    };
    egressRules = mkRulesOption {
      description = "connections outgoing to this interface (i.e. `oifname \${cfg.name}`)";
      notes = ''
        As of now, this ruleset is not expanded by other router submodules.
      '';
      default = "accept";
    };
  };

  config = {
    # rules for default cases across interfaces
    firewall.forwardRules = mkOrder 990 ''
      oifname == ${escapeNftablesStr ifCfg.name} ct status & dnat == dnat accept comment "NAT reflection, self"
    '';
    # rule implementation
    nftables.chains = mapRules {
      # TODO (maybe) make policies configurable
      ingress = ''
        type filter hook prerouting priority filter; policy drop;
        iifname != ${ifCfg.name} accept
        jump global comment "conntrack"
      '';
      input = ''
        # priority before NixOS native chain
        type filter hook input priority -50; policy drop;
        iifname != ${ifCfg.name} accept
        jump global comment "conntrack"
      '';
      forward = ''
        type filter hook forward priority filter; policy drop;
        iifname != ${ifCfg.name} accept
        jump global comment "conntrack"
      '';
      egress = ''
        type filter hook postrouting priority filter; policy drop;
        oifname != ${ifCfg.name} accept
        jump global comment "conntrack"
      '';
    };
  };

}
