{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  dhcpCfg = ifCfg.services.dhcp;
  routCfg = ifCfg.routing;
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkDefault mkIf;
  inherit (lib.options) mkEnableOption;
in
{

  options.services.dhcp = {
    enable = mkEnableOption ''
      a DHCP server (for IPv4) with sane default configurations
      (which can be individually overriden)

      most important:
      - assign address to interface
      - announce this router as DNS server
      - announce domain for interface

      The current implementation is based on systemd-networkd
    '';
  };

  config = mkIf dhcpCfg.enable {
    assertions = [
      {
        assertion = !isNull routCfg.ipv4Address;
        message = ".routing.ipv4Address required for DHCP server";
      }
    ];
    networkd = {
      linkConfig.RequiredForOnline = mkDefault false; # we are providing connectivity
      networkConfig = {
        DHCPServer = true;
      };
      dhcpServerConfig = {
        ServerAddress = routCfg.ipv4Address; # also assigns address to interface
        UplinkInterface = ":none"; # TODO rethink
        DNS = mkDefault "_server_address"; # TODO conditionally
        SendOption = singleton "15:string:${routCfg.domain}";
        EmitNTP = mkDefault false;
        EmitSIP = mkDefault false;
        EmitPOP3 = mkDefault false;
        EmitSMTP = mkDefault false;
        EmitLPR = mkDefault false;
      };
    };
  };

}
