{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  fwCfg = ifCfg.firewall;
  pingCfg = fwCfg.pingable;
  # helpers
  inherit (builtins) concatMap filter;
  inherit (lib) optionSets ruleFromList;
  inherit (lib.trivial) pipe;
  # type
  exposedIpType =
    with optionSets;
    subCombined [
      defaultRules
      commentRule
      multiIpRule
      multiSourceRule
      multiDeviceRule
    ];
  # results
  rules = concatMap (x: x._multiRules) pingCfg.devices;
  ipv4Rules = filter (x: x.ipVersion == "ipv4") rules;
  staticIPv4Rules = pipe ipv4Rules [
    (filter (x: x.source != "network"))
    (map ({ sourceIP, destination, ... }: "${sourceIP} . ${destination}"))
  ];
  networkIPv4Rules = pipe ipv4Rules [
    (filter (x: x.source == "network"))
    (map ({ destination, ... }: destination))
  ];
in
{

  options.firewall = {
    pingable = {
      # TODO verify all is non-exposed if list empty (esp. for IPv6)
      devices = lib.mkOption {
        description = "list of devices reachable by ping";
        type = lib.types.listOf exposedIpType;
        default = [ ];
      };
    };
  };

  # TODO overlapping sources break nftables rule generation
  config.firewall = {
    # TODO ipv6 support
    forwardRules = ''
      ${ruleFromList staticIPv4Rules (set: ''
        icmp type echo-request ip saddr . ip daddr == { ${set} } accept
      '')}
      ${ruleFromList networkIPv4Rules (set: ''
        icmp type echo-request ip saddr @${ifCfg.name}ipv4net ip daddr == { ${set} } accept
      '')}
    '';
  };

}
