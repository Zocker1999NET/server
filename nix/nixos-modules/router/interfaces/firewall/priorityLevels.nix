# documentation (in a wide sense) only!
# TODO (preformance) move outside of per-interface stuff
{ globalArg, config, ... }:
let
  inherit (globalArg) lib;
  inherit (lib) types;
  inherit (lib.options) mkOption;
  mkOpt =
    args:
    mkOption (
      {
        internal = true;
        readOnly = true;
      }
      // args
    );
  levelMod =
    { name, ... }:
    {
      options = {
        name = mkOpt {
          description = "(technical) name of order priority level";
          type = types.str;
          default = name;
        };
        fullName = mkOpt {
          description = "full or long name of order priority level";
          type = types.str;
        };
        description = mkOpt {
          description = "description of order priority level";
          type = types.lines;
        };
        # TODO (minor) allow recording of usages
        priority = mkOpt {
          description = "priority of order priority level";
          type = types.int;
        };
      };
    };
in
{

  # TODO better idea for rule management
  # - each module adds their own chains, all inside a given priority range
  #   - their priority is only considered for "fast aborts"
  #   - (as chains require all accepting)
  #   - the risk of simple overexposure through modules is minimized
  #   - but non overlapping is still better, to avoid mixing reasons
  # - each module adds two chains with +2 prio apart:
  #   - decision chain: where the actual rules are processed, but not enforced (esp. a drop)
  #   - enforcement chain: where the earlier remembered decision is processed
  # - admins have
  options.firewall.priorityLevels = mkOpt {
    description = ''
      Declared order priority levels for firewall rules.

      Those are considered a stable value.
      They may change in the future,
      but changes to existing values are considered a breaking change.
      Adding a new one is not considered a breaking change.
    '';
    type = types.attrsOf (types.submodule levelMod);
    default = {
      "l3_mgmt" = {
        fullName = "OSI L2/L3 management rules";
        priority = 500;
      };
      "l4_crucial" = {
        fullName = "OSI L4 crucial allow rules";
        descriiption = ''
          To allow traffic crucial to general network connectivity,
          e.g. certain ICMP & ICMPv6 traffic.
        '';
        priority = 700;
      };
      "l4_mgmt" = {
        fullName = "OSI L4 management rules";
        description = ''
          For protocols & ports not considered crucial to general network connectivity.
        '';
        priority = 900;
      };
    };
  };

  config = {
    # TODO (minor) assert levels do not overlap
  };

}
