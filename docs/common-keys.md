# Common Concept Keys

To avoid that different configurations start differing without notice,
for common concepts,
the configurations here must be marked with a SYNC key
which enables one to replace all occurencies of a certain setting semi-automatically.


## SYNC Key Format

Format: `===SYNC:[property]{:[stage]}===`

- RegEx for all identifiers: `[A-Za-z0-9/_-]+`
- `[property]` is the name of the property to be synced
- `:[stage]` allows to define that that value derivates because of a certain reason
    - can be omitted, then defaults to empty (i.e. `SYNC:prop` == `SYNC:prop:`)
    - either that value is meant for certain environments only (e.g. `bootstrap`)
    - otherwise something like: `YYYY-MM-DD-hh-mm/<reason>`


## Usage

As most file formats at least allow comments in explicit comment lines,
the SYNC key should be used at the line *before* the property to be keept in sync.

For example:
```python3
# ===SYNC:general/timezone===
timezone = "Europe/Berlin"
```

Or:
```preseed
# ===SYNC:general/timezone===
d-i time/zone string Europe/Berlin
```

## Defined Keys

Defined in YAML for machine parsable data.


```yaml

# values associated with me & shared between different OSes
general:
  meta:
    # properties of this repository
    repo:
      # public reachable url
      url: https://git.banananet.work/banananetwork/server
  network:
    ipv6_ula: "fde3:b424:b5ce::/48"
  ssh:
    authorized: |
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBdtHoYx74Dp2P/Th72JpY/vnSL8LUDG10HGoU+I162 thinkie 2019-06-04
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ322iTs4HagYWO5C/O8t2smxBOJNW68amar99H7f0kq zockerpc 2018-08-22
  time:
    zone: Europe/Berlin

# values of third-party systems
3rdparty:
  tailscale:
    ipv4: "100.64.0.0/10"
    ipv6: "fd7a:115c:a1e0::/48"

```

