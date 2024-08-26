# NixOS system profiles

In my case, those are to collect options common to a certain group of systems.
Their main goals & properties are:
- to make a system working for its intended platform / hypervisor
- also make it nice behaving (e.g. install optional agents)
- configuring stuff across the whole system
- do not introduce their own options
- do not introduce functionality which can be isolated
- each setup may import up to one profile
  - but profiles can, if they’re compatible, import each other

Some of them are opioniated in some ways,
read their descriptions before using.
