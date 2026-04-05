{ lib, ... }@flakeArg:
{ config, ... }:
let
  cfg = config.x-banananetwork.routerVM;
  compTsCfg = cfg.compat.tailscale;
  ts = config.services.tailscale;
  inherit (builtins) concatMap filter;
  inherit (lib) types;
  inherit (lib.modules) mkIf;
  inherit (lib.network) parseIP;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) pipe;
  mkDisableOption = arg: (lib.mkEnableOption arg) // { default = true; };
  routerFlags = {
    # in general: do not mess with the router module
    # see https://tailscale.com/kb/1241/tailscale-up
    accept-dns = false; # do not overwrite local DNS settings
    exit-node = ""; # use interface routes to selectively route traffic through Tailscale
    netfilter-mode = "off"; # prevent Tailscale from modifying nftables at all
    snat-subnet-routes = false; # use interface options for applying SNAT
    advertise-routes = mkIf (!isNull compTsCfg.advertiseRoutesFor) (
      pipe compTsCfg.advertiseRoutesFor [
        (concatMap (
          i: with cfg.interfaces.${i}.routing; [
            ipv4Address
            ipv6ULAPrefix
          ]
        ))
        (filter (v: !isNull v))
        (map (v: (parseIP v).network.cidrCompressed))
      ]
    );
  };
in
{

  _class = "nixos";

  options.x-banananetwork.routerVM.compat.tailscale = {
    enable = mkDisableOption ''
      options ensuring compatibility with Tailscale.

      These assertions & options only affect options of the Tailscale module
      and are hereby only effective if the Tailscale module is configured.

      Only disable these compatibility options
      after you checked why those are set.

      When using Tailscale, be aware of:
      - The {option}`.firewall.sources.expected` option for the Tailscale interface must be configured statically.
        These compat options aid by setting it to Tailscale’s default IPs `100.64.0.0/10` & `fd7a:115c:a1e0::/48`.
        If your tailnet operates in different ranges, you need to overwrite the {option}`.firewall.sources.expected` option,
        otherwise you may experience connection problems or security issues.
        You can & should leave the other compat options intact.
    '';

    advertiseRoutesFor = mkOption {
      description = ''
        List of interfaces, for which network’s routes will be advertised via Tailscale
        if {option}`x-banananetwork.routerVM.compat.tailscale.advertiseAuto` is enabled.

        This only refers to statically configured IPv4 & IPv6 subnets,
        as adapting the advertised routes to dynamically assigned addresses
        could trigger unexpected routing decisions,
        e.g. other nodes in a tailnet suddenly attempt to reach a local network via Tailscale
        or traffic users expected to always goes through Tailscale suddenly does not.

        Defaults to the interfaces which are listed to be reachable from the Tailscale interface.

        For weird edge cases:
        You can set this option to null to prevent `--advertise-routes=` from being set by the router module.
        E.g. an empty list would, by design, still trigger `--advertise-routes=` being added to the args.
      '';
      type = with types; nullOr (listOf ifName);
      default = cfg.interfaces.${ts.interfaceName}.routing.allowTo;
      defaultText = ''config.x-banananetwork.routerVM.interfaces''${config.services.tailscale.interfaceName}.routing.allowTo'';
      example = [
        "lan0"
      ];
    };
  };

  config = mkIf (cfg.enable && ts.enable && compTsCfg.enable) {

    assertions =
      let
        isOptSetOnce =
          optName: options:
          let
            trace = pref: val: lib.trace "${pref} = ${builtins.toJSON val}" val;
            nameRegex = "^--${lib.escapeRegex optName}(=.*)?$";
            matchOpt = text: builtins.match nameRegex text != null;
            matched = trace "matched" (builtins.filter matchOpt options);
          in
          builtins.length matched <= 1;
        assertOpt = optionsName: options: name: {
          assertion = isOptSetOnce name options;
          message = "--${name} in services.tailscale.${optionsName} is already configured by router settings & cannot be configured manually";
        };
        assertSetOpt = assertOpt "extraSetFlags" ts.extraSetFlags;
      in
      [
        {
          assertion = ts.useRoutingFeatures == "none";
          message = "services.tailscale.useRoutingFeatures will break security gurantees on a router, divert to manual configuration via router options";
        }
      ]
      ++ map assertSetOpt (builtins.attrNames routerFlags);

    services.tailscale = {
      setFlags = routerFlags;
      useRoutingFeatures = "none"; # just in case
    };

    x-banananetwork.routerVM.interfaces.${ts.interfaceName} = {
      # cannot rely on automatic detection of source addresses
      # because Tailscale assigns /32 & /128 bit masks
      # see https://github.com/tailscale/tailscale/issues/7340
      firewall.sources.expected = [
        # addresses according to: https://tailscale.com/kb/1033/ip-and-dns-addresses
        "100.64.0.0/10"
        "fd7a:115c:a1e0::/48"
      ];
    };

  };

}
