# IPv6 Space

All my devices are mainly grouped under the ULA `fde3:b424:b5ce::/48`.

The bits 49-64 are normally used to define following hierachy, ignoring exceptions:
- 49-56, `/56`: Location Code
  - locations `f0` - `ff` (i.e. `fde3:b424:b5ce:f000::/52`) are reserved for special cases, like VPNs
- 57-60, `/60`: Network Type Code
  - network type `f` usually notates management networks
  - one type might use multiple codes
- 61-64, `/64`: Network Code


## Home (`00`, `fde3:b424:b5ce:0000::/56`)

Encompasses all networks & devices mainly or temporarily located at my current living place.

Used network type codes & networks:
- `0`, `fde3:b424:b5ce:0000::/60`: normal operation networks
  - `1`, `fde3:b424:b5ce:0001::/64`: de.6nw.pve.boreth normal VM network
- `f`, `fde3:b424:b5ce:00f0::/60`: management networks
  - `0`, `fde3:b424:b5ce:00f0::/64`: management for switches


## Special (`ff`, `fde3:b424:b5ce:ff00::/56`)

Encompasses networks which are not bound to a specific location.

Used network type codes & networks:
- `ff`, `fde3:b424:b5ce:ffff::/64`: global-spanning VPN network, mainly used for peer-to-peer routing, may contain non-SLAAC IPs
