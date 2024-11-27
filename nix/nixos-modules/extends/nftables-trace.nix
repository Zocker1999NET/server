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
  traceMatch = {
    ipv4 = "meta iifname . ip saddr . ip daddr . ip protocol . th sport . th dport";
    ipv6 = "meta iifname . ip6 saddr . ip6 daddr . ip6 nexthdr . th sport . th dport";
  };
in
# TODO upstream
{

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
