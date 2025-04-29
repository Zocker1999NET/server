# Namespace: 6nw.de. / de.6nw

Everything that has a name is easier to manage,
at least I think so.
So everything of my IT that I need to manage is uniquely named.
This document aims to be a complete documentation of all sub namespaces
and their intended name scheme.
Through, be aware, this document will be a mix of intend & real world uses.

`6nw.de.` is the domain I own.
Only I am allowed to name stuff according to that namespace.
Feel free to map & derivate the rules of this namespace for your own uses
(licensed under CC-0),
but **please replace 6nw.de. with a domain your own and/or control**.


## Notation Scheme

The namespace scheme definition is alligned
on the definition of the domain name space used for DNS:

- Names according to this naming scheme are made of labels.
- Each label is assigned to a node or leaf
  in the tree data structure
  created by the namespace.
- Typically, through not always the case,
  a single entity is reflected by a leaf.
- Each sub-namespace corresponds to a node & vice versa.


### Root

However, different to DNS,
the root node of this namespace
is identified with the domain name `6nw.de.`.
Hence most names of this namespace
should also be usuable as FQDNs in DNS.


### Order of Labels

Names in this namespace can be written down in

- "normal" DNS notation (i.e. with root as suffix: `6nw.de.`)
- reversed DNS notation (i.e. as prefix: `de.6nw`)

Which notation is used depends on the use case.
Hence, assuming "normal" and reversed notation respectively,
`alpha.pc.6nw.de.` and `de.6nw.pc.alpha` refer to the same object.
In general, when the entity or system where the name is used on or in:

- natively supports the DNS hierachy
  (e.g. DNS, FreeIPA, Windows AD)
    - the name must be used in any scheme native for to that system
      (e.g. PC `de.6nw.pc.alpha` will be)
- is structured in a hierachy
  (e.g. LDAP, file systems, Java packages),
    - reverse DNS notation should be used
      (PC specific files stored in `de/6nw/pc/alpha`, or alternatively `de.6nw.pc/alpha`)
- is often referred to in a namespace-specific setting
    - (e.g. storage media)
    - "normal" DNS notation should be used

For example: As operating systems often support the DNS hierachy
for their own name by splitting that into a hostname & a FQDN,
a PC called `de.6nw.pc.alpha` will be configured
with the hostname `alpha` in the domain `pc.6nw.de.`,
resulting in its FQDN to become `alpha.pc.6nw.de.`


### Caveats

- By definition, labels are not limited to a certain character set.
  Through special characters should only be used wisely.

- The separator used to join labels to a fully qualified name
  is not required to be a dot (`.`).
  If a fully qualified name is used in another hierachical system,
  a different separator can be used to make full use of that system’s hierachy.
  (e.g. `/` in URLs or file systems).

- Because this document is structured hierachily,
  in most cases reversed DNS notation will be used further on.
  If "normal" DNS notation is used here,
  the names will end with a period `.`.
  In real world uses, the leading period might be omitted,
  hence detecting the hierachical order of the labels might be hard.

- As the namespace definition crosses system boundaries,
  names may be written down in a scheme not defined by this document.
  In certain cases, this means that different separators are used in one name
  or that with the use of a different separator, a different order of labels is used.
  Examples are:
    - a ZFS dataset `de.6nw.zfs.pool.dataset` might be referred to as `pool.zfs.6nw.de/dataset`



## Full Namespace

The full namespace is defined & used as follows.
One asterisk `*` is used as a placeholder for a single label
or, in some cases, for part of a label.
Two astersiks `**` is used as a placeholder for one or more of labels.
Further informations on a sub-namespace might be found in following sections.

- `de.6nw` (root)
  - `disk.*` (bare storage media)
    - `luks` (its LUKS partition)
    - `pv` (its LVM physical volume)
  - `inv` (inventar system)
  - `lvm.*` (LVM volume group)
    - `*` (LVM logical volume)
  - `o` (other stuff)
  - `pc.*` (personal computer / phone / etc.)
    - `vm.*` (VM bound to that device)
  - `pve.*` (hypervisor cluster)
    - `*` (name, VM or container bound to that cluster)
    - `ct*` (number, VM bound to that cluster)
    - `vm*` (number, container bound to that cluster)
  - `srv.*` (baremetal server)
  - `temp.*` (temporary systems, e.g. installation ISOs & targets)
  - `zfs.*` (ZFS pool & root dataset)
    - `**` (child datesets)
