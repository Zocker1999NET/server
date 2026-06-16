{ lib, libBNet, ... }@flakeArg:
{ config, ... }:
let
  routerCfg = config.x-banananetwork.routerVM;
  cfg = routerCfg.dns;
  inherit (lib.lists) forEach;
  inherit (libBNet) types;
in
{

  _class = "nixos";

  options.x-banananetwork.routerVM.dns = {

    upstreams = lib.mkOption {
      description = ''
        List of DNS servers used by DNS server for clients.
      '';
      type = with types; listOf str;
    };
    fallbacks = lib.mkOption {
      description = ''
        List of DNS servers used as fallbacks
        (i.e. when all upstreams are unreachable).
        Used by DNS server for clients.
      '';
      type = with types; listOf str;
      default = [ ];
    };
    bootstraps = lib.mkOption {
      description = ''
        List of DNS servers used to bootstrap list of other DNS servers.
        Not used by DNS server for clients.
      '';
      type = with types; listOf str;
      default = cfg.localFallbacks;
      defaultText = lib.literalExpression "config.x-banananetwork.routerVM.dns.localFallbacks";
    };
    localFallbacks = lib.mkOption {
      description = ''
        List of DNS servers used as local fallbacks, i.e. added aside of own DNS server to {file}`/etc/resolv.conf` of router itself.
      '';
      type = with types; listOf ipAddress;
      default = [ ];
    };

    filterlists = lib.mkOption {
      description = ''
        List of URLs of filterlists which entries should be blocked.
      '';
      type = with types; listOf str;
      default = [ ];
    };

    webui = {
      port = lib.mkOption {
        description = ''
          Port under which the AdGuard Home web interface will be made accessible.
        '';
        type = types.port;
        default = 3000;
      };
      username = lib.mkOption {
        description = ''
          Username for AdGuard Home admin account.
        '';
        type = types.str;
        default = "admin";
        example = "myuser";
      };
      password = lib.mkOption {
        description = ''
          Hash for AdGuard Home admin account.
          Can be created with .e.g. {command}`mkpasswd --method=bcrypt`'

          For more info, read in the [Adguard Home Wiki](https://github.com/AdguardTeam/AdguardHome/wiki/Configuration#reset-web-password)
        '';
        type = types.str;
      };
    };

  };

  config = lib.mkIf routerCfg.enable {

    # DNS server
    # TODO (feature) migrate to blocky, seems way better & automated for our use case: https://0xerr0r.github.io/blocky/latest/
    # TODO (feature) exclude router from filtering itself (without config)
    # TODO (feature) add support for https://opennic.org/
    # TODO (upstream, minor) change NixOS upstream module to remove yaml-merge dependency if not required

    services.adguardhome = {
      enable = true;
      allowDHCP = false;
      mutableSettings = false;
      port = cfg.webui.port;
      settings = {
        http = {
          session_ttl = "5:00";
        };
        users = lib.singleton {
          name = cfg.webui.username;
          password = cfg.webui.password;
        };
        auth_attempts = 5;
        block_auth_min = 5;
        dns = {
          port = 53;
          anonymize_client_ip = false;
          ratelimit = 100; # queries / second
          ratelimit_subnet_len_ipv4 = 32;
          ratelimit_subnet_len_ipv6 = 128;
          refuse_any = true;
          upstream_dns = cfg.upstreams;
          fallback_dns = cfg.fallbacks;
          bootstrap_dns = cfg.bootstraps;
          local_ptr_upstreams = [
            # TODO
          ];
          upstream_mode = "load_balance";
          upstream_timeout = "10s";
          use_http3_upstream = true;
          enable_dnssec = true;
          cache_time = 36000;
          resolve_clients = true;
          serve_plain_dns = true;
          hostsfile_enabled = false;
        };
        filtering = {
          protection_enabled = true;
          filtering_enabled = true;
          blocking_mode = "nxdomain";
          blocked_response_ttl = 60; # seconds
          safe_search.enabled = false;
          safebrowsing_enabled = true;
        };
        querylog = {
          enabled = true;
          file_enabled = true;
          interval = "${toString (2 * 24)}h";
        };
        statistics = {
          enabled = true;
          interval = "${toString (7 * 24)}h";
        };
        filters = forEach cfg.filterlists (url: {
          enabled = true;
          inherit url;
          name = url;
          ID = builtins.hashString "sha1" url;
        });
        dhcp.enabled = false;
        tls.enabled = false;
        log.file = "syslog"; # journal
      };
    };
    # TODO remove after https://github.com/NixOS/nixpkgs/pull/532141
    systemd.services.adguardhome.serviceConfig.RestrictAddressFamilies = lib.optional (
      config.services.adguardhome.settings.log.file or "" == "syslog"
    ) "AF_UNIX";

  };

}
