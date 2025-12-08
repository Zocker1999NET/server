{
  lib,
  writeText,
  python3Packages,
  iproute2,
  mypy,
  nftables,
}:
let
  version = "2024.12.22";
  project_toml = writeText "nft-update-addresses_pyproject" ''
    [build-system]
    requires = ["setuptools >= 61.0"]
    build-backend = "setuptools.build_meta"
    [project]
    name = "nft-update-addresses"
    version = "${version}"
    requires-python = ">= 3.11"
    [project.scripts]
    nft-update-addresses = "update_addresses:main"
  '';
in
python3Packages.buildPythonPackage {
  name = "nft-update-addresses";
  inherit version;
  format = "pyproject";

  build-system = lib.singleton python3Packages.setuptools;

  dependencies = with python3Packages; [
    attrs
    setuptools
    systemd-python
  ];

  propagatedBuildInputs = [
    iproute2
    nftables
  ];

  unpackPhase = ''
    cp ${project_toml} ./pyproject.toml
    cp -r ${./../../../update-addresses} ./src
    chmod --recursive u=rwX ./src  # required so further build steps can create wrapper files
    ${lib.getExe mypy} --strict ./src
  '';

  meta = {
    description = "Auto-updates nftables sets to reflect dynamic IPs / nets used on dynamic setups, including SLAAC addresses of clients";
    longDescription = ''
      > (TL;DR in catchy:) This service will solve most of your problems in dynamic IP setups!!

      This service is designed for networking setups without static IPs
      and with IP rotations at runtime in mind.
      It can be helpful when configuring a router based on NixOS or any other Linux distribution.

      With this service, I already implemented a rather simple NixOS router setup
      working with dynamically assigned IPs & prefixes via DHCP & DHCPv6 prefix delegation.
      You can also find this router project in [my flake](https://git.banananet.work/banananetwork/server).
      With this router setup, I also throughly test every change to this script before publishing
      as these changes will also be automatically pushed to my server setup as well.
      So while I cannot give any gurantee, this service should be fairly stable.

      For each interface defined in its config file,
      it continuously monitors for IP changes and reflects them into the sets
      with `{ifname}v{ipVersion}` as their name’s prefix.
      Most sets & maps should work flawless in multi IP/prefix setups as well.

      Available sets & maps are:
      - `{prefix}addr`: IP addresses of the host itself
        - excluding link-locals
        - including IPv4 private networks
        - excluding IPv6 unique link local (to identify requests to public routable addresses)
        - example use: `iifname != lan0 ip daddr @lan0v4addr drop`
      - `{prefix}net`: IP networks of the host’s IP addresses
        - excluding link-locals
        - including IPv4 private networks
        - including IPv6 unique link local (to identify target networks in forwarding rules)
        - example use: `iifname lan0 ip saddr @lan0v6net accept`
      - `{prefix}dnat{protocol}`: map of ports to IPs with destination port which might be DNATed to (v6 only)
        - `protocol` means all OSI layer 4 protocols with ports supported by nftables
          (currently `dccp`, `sctp`, `tcp, `udp`, `udplite`)
        - example use: `dnat ip6 to tcp dport map @lan0v6dnattcp`
      - `{prefix}exp{protocol}`: set of IPs with destination ports which might be exposed (v6 only)
        - `protocol` means the same as for `dnat` map
        - example use: `ip6 daddr . tcp dport @lan0v6exptcp accept`
      - `{prefix}_{mac}`: modified EUI64 SLAAC address for that MAC using the prefix used by the host itself (v6 only)
        - will only be created for MAC addresses listed in the config file
        - WARNING: not stable on multi-prefix setups, fluctuates based on the latest update
        - example use: `ip6 saddr @lan0v6_aabbccddeeff tcp dport 53 reject comment "no dns for this host"`

      There is also a NixOS module available easing the configuration: {option}`services.nft-update-addresses`.
      Looking into the Nix files can also be helpful for non NixOS setups
      as they provide an example for a sandboxed systemd service implementation.

      If you can & want to automate the creation of said sets & maps,
      the script provides a CLI flag `--output-set-definitions`
      with the definitions of all sets & maps supplied by the service when executed with the same config.
      Importing these definitions before starting the service is required,
      but also enables you to load rules using these before the service is fully operational
      (especially perfect for NixOS setups).

      This service is built crash anytime it experiences a probably fatal error
      (i.e. unparsable IP updates or failing to populate nftables).
      Therefore, a systemd service setup with aggressive restart policies (already included in my module)
      and a monitoring of said systemd service are advisable.
    '';
    mainProgram = "nft-update-addresses";
  };
}
