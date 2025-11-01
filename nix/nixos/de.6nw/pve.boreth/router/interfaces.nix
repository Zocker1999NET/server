{ lib, outputs, ... }@flakeArg:
{ config, options, ... }:
let
  inherit (lib.lists) singleton;
in
{
  config.x-banananetwork.routerVM.interfaces = {

    "wan0" = {
      kind = "wan-rfc7084";
      description = "WAN device";
      workarounds = {
        dhcpv6IsAvmFritzBox = true;
        dhcpv6PrefixDelegationWithoutAddress = true;
      };
    };

    "lan0" = {
      kind = "lan-rfc7084";
      description = "VM LAN";
      routing = {
        ipv4Address = "10.32.1.1/24";
        ipv6ULAPrefix = "fde3:b424:b5ce:1::/64";
        ipv6InterfaceId = "::1";
        upstream = "wan0";
        upstreamIdx = 0;
      };
      # TODO migrate lanEmitRejections = true;
      devices = {
        "truenas" = {
          mac = "BC:24:11:41:8F:D8";
          staticIPv4 = "10.32.1.110";
          forwardedPorts = {
            "webui" = {
              sources = singleton "network";
              wanPort = 8888;
              lanPort = 443;
            };
            "ssh" = {
              sources = singleton "network";
              wanPort = 2222;
              lanPort = 22;
            };
          };
        };
        "nixnas" = {
          mac = "BC:24:11:1D:8E:2E";
          staticIPv4 = "10.32.1.111";
          forwardedPorts = {
            ssh = {
              sources = singleton "network";
              wanPort = 22111;
              lanPort = 22;
            };
            smb = {
              sources = singleton "network";
              wanPort = 445;
              lanPort = 445;
            };
          };
        };
        "dns" = {
          mac = "BC:24:11:04:C7:A0";
          staticIPv4 = "10.32.1.112";
          forwardedPorts = {
            ssh = {
              sources = singleton "network";
              wanPort = 22112;
              lanPort = 22;
            };
            dns-tcp = {
              sources = singleton "network";
              protocol = "tcp";
              wanPort = 53;
              lanPort = 53;
            };
            dns-udp = {
              sources = singleton "network";
              protocol = "udp";
              wanPort = 53;
              lanPort = 53;
            };
          };
        };
        "pbs" = {
          mac = "BC:24:11:A5:69:63";
          staticIPv4 = "10.32.1.120";
          forwardedPorts = {
            ssh = {
              sources = singleton "network";
              wanPort = 22120;
              lanPort = 22;
            };
            pbs = {
              sources = singleton "network";
              wanPort = 8007;
              lanPort = 8007;
            };
          };
        };
        "immich" = {
          mac = "BC:24:11:5A:58:FC";
          staticIPv4 = "10.32.1.210";
          forwardedPorts = {
            ssh = {
              sources = singleton "network";
              wanPort = 22210;
              lanPort = 22;
            };
            immich = {
              sources = singleton "network";
              wanPort = 3001;
              lanPort = 3001;
            };
          };
        };
        "debian-deploy" = {
          mac = "BC:24:11:50:0C:F1";
          exposedPorts.ssh = {
            sources = singleton "network";
            port = 22;
          };
        };
        "nix-builder" = {
          mac = "BC:24:11:B5:58:0C";
          exposedPorts = {
            ssh = {
              sources = singleton "network";
              port = 22;
            };
          };
        };
      };
    };

    "tailscale0" = {
      kind = "custom";
      description = "Tailscale Network";
      routing = {
        plain = [
          "lan0"
        ];
      };
      srcnat.both.enableFor = [
        "wan0"
      ];
    };

  };
}
