# NixOS Router Framework

This is another NixOS router framework working better for my usecase


## Features

- designed for environments with dynamic IP address configs
  - uses DHCPv4 on WAN to get private or public IPv4
  - uses DHCPv6 on WAN to get public IPv6 prefix via DHCP prefix delegation (DHCP-PD)
- allows easy exposing & forwarding of ports
  - exposed port rules auto-adapt to changing IPv6 prefix
  - port forwardings (i.e. DNAT) work on IPv4 & IPv6
  - configuring them only requires MAC & static IPv4
- configures AdGuard Home as filtering DNS server for clients
- stays mostly compatible with common NixOS networking & firewall configs, e.g.:
  - `.openFirewall` & `.allowedTCPPorts`/`.allowedUDPPorts` options continue to work (opens port on all interfaces)

I also develop a NixOS test which tries to verify that these features work as expected, which will be published later in this flake.


### Restrictions

Given all features, this module comes up with a few restrictions (; incomplete list):

- supports only one WAN & one LAN interface
- does not allow easy integration of a VPN network
- fully relies on systemd-networkd for DHCPv4/v6 client, DHCPv4 server & prefix-delegated router advertisements

It is not impossible or really, really hard to overcome these limitations but it may require changing this module in substantional ways.


## Example Use

(**TODO** link to yet uncommited stuff)


## Inspirators

I was inspired to implement this by other, similar projects, which were sadly lacking some features highly important to me.
However, as a form of credit & to provide further ressources to you:

- [nixos-router](https://github.com/chayleaf/nixos-router) by [@chayleaf](https://github.com/chayleaf)
  - utilizes network namespaces (mine does not!)
  - because of that, (at time of writing) it ditched systemd-networkd for now, which I wanted to use
  - was not designed for a environment with dynamic IPs
- [NixOS based router in 2023](https://github.com/ghostbuster91/blogposts/blob/a2374f0039f8cdf4faddeaaa0347661ffc2ec7cf/router2023-part2/main.md) by [@ghostbuster91](https://github.com/ghostbuster91)
  - was a useful ressource in creating my module


## Further Content

Which has nothing to do in particular with this module,
but which were discovered while implementing it.

### nftables

- nftables sets do not support a the typical wildcard `*` for non IP addresses (i.e. protocols, ports, etc.)
  BUT nftables supports "CIDR-like" syntax for all numeric values,
  e.g. `meta mark == 0/2`, hence `0/0` is kind of a wildcard for everything.
- You can match ports for several OSI L4 protocols in a single set by leveraging the type concatenation `inet_proto` & `inet_service`,
  which is matched by `meta l4proto . th dport` (or `th sport`).
  This works for all protocols which declare their source & destination ports in the first or second 16 bits of the header (read manpage on how `th` works).
  This is at least the case for `dccp`, `sctp`, `tcp`, `udp` & `udplite`.
  More funnily, you can technically use `th sport` to match `icmp` & `icmpv6` types & codes together, through this requires some caution.
