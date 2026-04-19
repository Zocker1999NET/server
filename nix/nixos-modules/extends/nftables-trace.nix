{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.networking.nftables;
  inherit (builtins) concatStringsSep;
  inherit (lib) types;
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) mkEnableOption mkOption;
  # TODO (minor) reuse generic translator from router implemenation
  # TODO cannot match for "meta iifname", because then type of set becomes invalid
  #   type is then used as "type verdict . …" making valid matching of anything impossible
  #   to check, see output of "nft list ruleset"
  traceMatch = {
    ipv4 = "ip saddr . ip daddr . ip protocol . th sport . th dport";
    ipv6 = "ip6 saddr . ip6 daddr . ip6 nexthdr . th sport . th dport";
  };
in
# TODO upstream
{

  _class = "nixos";

  options.networking.nftables = {
    traceIPv4 = mkOption {
      description = ''
        Which traffic to trace with nftrace.

        Format is an nftables set entry matching:
        `${traceMatch.ipv4}`

        Be aware that you can wildcard most non-IP fields with `0/0`.
      '';
      type = types.listOf types.str;
      default = [ ];
      example = lib.literalExpression ''
        [
          # Trace TCP traffic from 192.0.2.1:12345 to 198.51.100.2:80
          "192.0.2.1 . 198.51.100.2 . tcp . 12345 . 80"
          # Trace UDP traffic from any source to 203.0.113.5:53
          "0.0.0.0/0 . 203.0.113.5 . udp . 0/0 . 53"
          # Wildcard all non-IP fields (match any protocol/port)
          "10.0.0.1 . 10.0.0.2 . 0/0 . 0/0 . 0/0"
        ]
      '';
    };
    traceIPv6 = mkOption {
      description = ''
        Which traffic to trace with nftrace.

        Format is an nftables set entry matching:
        `${traceMatch.ipv6}`

        Be aware that you can wildcard most non-IP fields with `0/0`.
      '';
      type = types.listOf types.str;
      default = [ ];
      example = lib.literalExpression ''
        [
          # Trace TCP traffic from [2001:db8::1]:12345 to [2001:db8::2]:80
          "2001:db8::1 . 2001:db8::2 . tcp . 12345 . 80"
          # Trace UDP traffic from any source to [2001:db8::5]:53
          "::/0 . 2001:db8::5 . udp . 0/0 . 53"
          # Wildcard all non-IP fields (match any protocol/port)
          "2001:db8::a . 2001:db8::b . 0/0 . 0/0 . 0/0"
        ]
      '';
    };
    traceToJournal = mkEnableOption ''
      a service pushing nftrace logs to the systemd journal.

      This does not enable tracing of packets,
      you need to configure such rules yourself.

      Be aware that, depending on the configuration,
      this might fill up your journal and
      could enable easier denial of service (DoS) attacks'';
  };

  config = {
    networking.nftables.tables."nixos-fw".content = mkMerge [
      (mkIf (cfg.traceIPv4 != [ ]) ''
        set ipv4-trace {
          typeof ${traceMatch.ipv4}
          flags interval
          elements = { ${concatStringsSep ", " cfg.traceIPv4} }
        }
        chain trace-ipv4 {
          type filter hook prerouting priority -301; policy accept;
          ${traceMatch.ipv4} == @ipv4-trace meta nftrace set 1
        }
      '')
      (mkIf (cfg.traceIPv6 != [ ]) ''
        set ipv6-trace {
          typeof ${traceMatch.ipv6}
          flags interval
          elements = { ${concatStringsSep ", " cfg.traceIPv6} }
        }
        chain trace-ipv6 {
          type filter hook prerouting priority -301; policy accept;
          ${traceMatch.ipv6} == @ipv6-trace meta nftrace set 1
        }
      '')
    ];
    systemd.services.nftables-trace = mkIf cfg.traceToJournal {
      description = "nftables trace monitor to journal logger";
      after = singleton "nftables.service";
      wantedBy = singleton "multi-user.target";
      serviceConfig = {
        Type = "simple";
        ExecStart = singleton "${getExe pkgs.nftables} monitor trace";
      };
    };
  };

}
