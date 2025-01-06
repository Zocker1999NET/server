{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  ifOpts = interface.options;
  inherit (builtins)
    attrValues
    concatMap
    filter
    listToAttrs
    mapAttrs
    ;
  inherit (lib) types;
  inherit (lib.attrsets) filterAttrs nameValuePair;
  inherit (lib.modules) mkDefault;
  inherit (lib.network) formatMAC;
  inherit (lib.options) literalExpression mkOption;
  inherit (lib.trivial) pipe;
  # values
  devs = pipe ifCfg.devices [
    attrValues
    (filter (x: x.enable))
  ];
in
{

  options = {

    devices = mkOption {
      description = ''
        Describes properties for a LAN device
        (e.g. DHCP static leases & port forwardings).

        For IPv6 based rules to work,
        devices must use their stable EUI64 IPv6 address
        for the prefix announced via SLAAC.
        You can recognise those as they reflect the MAC address of the interface.

        The router cannot forward ports for devices only using
        private IPv6 addresses according to
        RFC 4941 (IPv6 privacy extensions)
        or RFC 7217 (stable private IPv6 addresses).
      '';
      type = types.attrsOf (
        types.submodule (
          { name, ... }@device:
          let
            dev = device.config;
            devOpts = device.options;
            # types
            # TODO cannot use types.extendsSubmodule yet, because ifOpts.exposed.devicePorts is listOf, not attrsOf
            exposedPortType =
              with lib.optionSets;
              subCombined [
                commentRuleName
                enableRule
                ifOpts.firewall.exposed.devicePorts
                { config.device = dev.mac; }
                { config.ipVersions = mkDefault [ "ipv6" ]; } # TODO make IPv4 also default when auto-detection is in place
              ];
            forwardedPortType =
              with lib.optionSets;
              subCombined [
                commentRuleName
                enableRule
                exposeRule
                ifOpts.dstnat.forUpstreams
                { config.device = dev.mac; }
              ];
          in
          {
            options = {
              enable = mkOption {
                description = "Configure rules for this device";
                type = types.bool;
                default = true;
              };
              name = mkOption {
                description = "hostname of the device";
                type = lib.hostnameType;
                default = name;
              };
              description = mkOption {
                description = "Descriptive, human-readable name for that device";
                type = types.str;
                default = name;
              };
              mac = mkOption {
                description = "MAC Address of device";
                type = types.eui48;
              };
              staticIPv4 = mkOption {
                description = "Static DHCPv4 lease address for device";
                type = with types; nullOr ipv4AddressPlain;
                default = null;
              };
              fullyExposed = lib.mkEnableOption "to fully expose this device via IPv6, making other firewall rules except NATs irrelevant";
              forwardedExposed = lib.mkDisableOption ''
                Whether to enable automatic exposure of port forwardings via IPv6.

                For example, if a port forwarding from 8080 to 80 is established,
                then the port 80 will also be exposed directly for the device’s IPv6,
                making using NAT optional'';
              allowICMPEcho = lib.mkEnableOption "forwarding of ICMP echos via IPv6 to the device" // {
                default = dev.exposedPorts != [ ];
                defaultText = literalExpression ''devCfg.exposedPorts != [ ]'';
              };
              exposedPorts = mkOption {
                description = ''
                  Ports which should be accessible to the public via IPv6.

                  Adding one port does enable ICMP pings to that host.
                '';
                type = types.attrsOf exposedPortType;
                default = { };
              };
              forwardedPorts = mkOption {
                description = ''
                  Ports which should be forwarded from the router WAN IPv4 & v6 address to this device.

                  The port is then made accessible using DNAT
                  on all packets sent to the router’s public interface
                  via IPv4 (if `config`{staticIPv4}` is set) and IPv6.
                '';
                type = types.attrsOf (
                  types.subCombined [
                    forwardedPortType
                    {
                      options.expose = mkOption {
                        default = dev.forwardedExposed;
                        defaultText = literalExpression "devCfg.forwardedExposed";
                      };
                    }
                  ]
                );
                default = { };
                example = {
                  http = {
                    wanPort = 8080;
                    lanPort = 80;
                  };
                  quic = {
                    lanPort = 443;
                    protocol = "udp";
                  };
                };
              };
              nftablesIPv4Dest = lib.mkOutputOption { default = dev.staticIPv4; };
              nftablesIPv6Dest = lib.mkOutputOption { default = ''@${ifCfg.name}v6_${lib.formatMAC dev.mac}''; };
              nftablesForwardingRules = lib.mkOutputOption {
                default =
                  if dev.fullyExposed then
                    ''
                      ip6 daddr ${dev.nftablesIPv6Dest} accept comment ${lib.escapeNftablesStr "${dev.description} full exposure"}
                    ''
                  else
                    ''
                      ${lib.filterMapJoin "\n" dev.exposedPorts (ep: ep.nftablesForwardingRules)}
                      ${lib.filterMapJoin "\n" dev.forwardedPorts (fw: fw.nftablesForwardingRules)}
                      ${lib.optionalString (
                        dev.nftablesIPv4Dest != null
                      ) "ip daddr ${dev.nftablesIPv4Dest} jump drop-reject"}
                      ip6 daddr ${dev.nftablesIPv6Dest} jump drop-reject
                    '';
              };
              nftablesPreroutingRules = lib.mkOutputOption {
                default = lib.filterMapJoin "\n" dev.forwardedPorts (fw: fw.nftablesPreroutingRules);
              };
            };
            config = {
              exposedPorts = pipe dev.forwardedPorts [
                (filterAttrs (_: fw: fw.expose))
                (mapAttrs (
                  _: fw:
                  fw._cloneFor devOpts.exposedPorts
                  // {
                    comment = "${fw.comment} (exposed port forwarding)";
                    port = fw._clone.lanPort;
                  }
                ))
              ];
            };
          }
        )
      );
      default = { };
    };

  };

  config = {

    dstnat.forUpstreams = concatMap (
      d:
      pipe d.forwardedPorts [
        attrValues
        (filter (fw: fw.enable))
        (map (fw: fw._cloneFor ifOpts.dstnat.forUpstreams // { comment = "${d.name} - ${fw.comment}"; }))
      ]
    ) devs;

    firewall = {
      exposed = {
        fullDevices = pipe devs [
          (filter (d: d.fullyExposed))
          (map (d: {
            comment = d.name;
            device = d.mac;
          }))
        ];
        devicePorts = concatMap (
          d:
          pipe d.exposedPorts [
            attrValues
            (filter (ex: ex.enable))
            (map (
              ex: ex._cloneFor ifOpts.firewall.exposed.devicePorts // { comment = "${d.name} - ${ex.comment}"; }
            ))
          ]
        ) devs;
      };
    };

    networkd.dhcpServerStaticLeases = pipe devs [
      (filter (d: d.staticIPv4 != null))
      (map (d: {
        MACAddress = d.mac;
        Address = d.staticIPv4;
      }))
    ];

    # TODO ICMP mappings

    nft-update-addresses.config.macs = map (d: d.mac) devs;

    references = {
      macToIPv4 = pipe devs [
        (filter (d: d.staticIPv4 != null))
        (map (d: nameValuePair (formatMAC d.mac) d.staticIPv4))
        listToAttrs
      ];
    };

  };

}
