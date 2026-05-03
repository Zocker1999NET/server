{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  fwCfg = ifCfg.firewall;
  inCfg = fwCfg.input;
  inherit (lib) mapListJoin;
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf;
in
{

  options.firewall.input = {
    checkDestination = lib.mkDisableOption ''
      checking packets incoming to the router as well.

      If enabled, the router only accepts packets for itself incoming on this interface
      if it uses an address which is assigned to that interface.
      Further, destination addresses from interfaces defined in `routing.allowTo`
      are allowed as well.'';
  };

  config = mkIf inCfg.checkDestination {
    # TODO apply filter to dstnat rules
    nftables.chains.inputDestination = ''
      type filter hook input priority filter - 10; policy drop;
      iifname != ${ifCfg.name} accept
      # TODO what about pkttype other ?
      meta pkttype { broadcast, multicast } accept comment "we cannot determine here if destination was chosen correctly"
      # always allow from link-locals, as those must be correct
      # (input chains packets are already checked for a local IP by the system)
      ip daddr @ipv4-linklocal accept
      ip6 daddr @ipv6-linklocal accept
      # other accepted addresses (including from interfaces, which are allowed to send packets here out)
      ${mapListJoin "" (singleton ifCfg.name ++ ifCfg.routing.allowTo) (ifname: ''
        ip daddr == @${ifname}v4addr accept
        ip6 daddr == @${ifname}v6addr accept
      '')}
    '';
  };

}
