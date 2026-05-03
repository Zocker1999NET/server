{ globalArg, others, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  fwCfg = ifCfg.firewall;
  inherit (builtins)
    attrNames
    concatStringsSep
    elem
    filter
    ;
  inherit (lib) types;
  inherit (lib.attrsets) filterAttrs mapAttrs' nameValuePair;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) pipe;
  activeRules = filterAttrs (_: rules: rules != "") fwCfg.forwardToRules;
in
{

  options.firewall = {
    # TODO support interface groups
    forwardToRules = mkOption {
      description = ''
        Forward rules for packets from this interface to the defined ones.

        I.e. the example declares rules applied to packets
        from this interface to a interface "wan0".

        Because of the security implications of this setting,
        the use of commonly defined order priority levels is recommended.

        - 700: OSI L2/L3, block
        - 800: crucial protocols (ICMP & co.), block & allow
          - allow because some ICMP traffic is crucial for any connectivity to establish
        - 900: OSI L4, block
        - 1000: OSI L4, "exposed" allow

        System administrators are, of course, allowed, to place their rules as they see fit.
        Module authors are strictly advised to follow these conventions
        to aid system administrators to keep their systems secure.
        If you as a module author require a new priority level to place their rules appropriately,
        feel free to request a new priority level so it can be documented here.
        The addition of a new priority level is considered a breaking change,
        as system administrators may want to change their rules placement accordingly.
      '';
      type = types.attrsOf types.lines;
      default = { };
      example = {
        wan0 = "accept";
      };
    };
  };

  config = {
    assertions = [
      (
        let
          known = map (x: x.name) others;
          unknown = pipe activeRules [
            attrNames
            (filter (x: !elem x known))
          ];
        in
        {
          assertion = unknown == [ ];
          message = "Unknown interfaces with forwardToRules: ${toString unknown}";
        }
      )
    ];

    # TODO support interface groups
    firewall.forwardRules = pipe activeRules [
      attrNames
      (map (dest: "oifname == ${dest} jump ${ifCfg.nftables.namePrefix}-forwardTo-${dest}"))
      (concatStringsSep "\n")
    ];

    nftables.chains = mapAttrs' (dest: nameValuePair "forwardTo-${dest}") activeRules;
  };

}
