{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  snatCfg = ifCfg.srcnat;
  inherit (builtins) elem;
  # options
  validIpVer = [
    "both"
    "IPv4"
    "IPv6"
  ];
  snatOpts =
    ipVer:
    assert elem ipVer validIpVer;
    {
      enableFor = lib.mkOption {
        description = ''
          Outgoing interfaces for which
          ${ipVer} packets from this interface will be SNATed.
        '';
        type = with lib.types; listOf ifName;
        default = [ ];
      };
    };
in
{

  options.srcnat = {
    both = snatOpts "both";
    ipv4 = snatOpts "IPv4";
    ipv6 = snatOpts "IPv6";
  };

  config = {
    # rules are established globally
    srcnat = {
      ipv4 = snatCfg.both;
      ipv6 = snatCfg.both;
    };
  };

}
