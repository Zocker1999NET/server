{
  inputs,
  lib,
  self,
  ...
}@flakeArg:
# TODO upstream
let
  inherit (builtins) concatLists concatStringsSep elem;
  inherit (lib.lists) toList;
  inherit (lib.trivial) flip pipe;
  concatRepeat =
    sep: str: count:
    assert count >= 0;
    if count == 0 then
      ""
    else if count == 1 then
      str
    else
      "(${str}${sep}){${toString (count - 1)}}${str}";
  concatGroup = patterns: "(${concatStringsSep "|" patterns})";
  repeatOptional =
    sep: pattern: count:
    assert count >= 0;
    if count == 0 then
      ""
    else if count == 1 then
      pattern
    else
      "(${pattern}${sep}){0,${toString (count - 1)}}${pattern}";
  matchType =
    { description, pattern }: lib.types.strMatching "^${pattern}$" // { inherit description; };
  # === regex parts
  hexChar = "[0-9A-Fa-f]";
  ipv4Block = "(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])";
  euiHexBlock = "(${hexChar}){2}";
  euiWith = concatRepeat "[.:_-]?" euiHexBlock;
  eui48 = euiWith 6;
  eui64 = euiWith 8;
  ipv4Addr = concatRepeat "\\." ipv4Block 4;
  ipv6Block = "(${hexChar}){0,4}";
  ipv6Addr =
    let
      genVariant =
        max: rightNum:
        let
          leftNum = max - rightNum - 1;
          leftPart = concatRepeat ":" ipv6Block leftNum;
          middlePart = lib.optionalString (rightNum == 0) "(${ipv6Block})?"; # full address only required once
          rightPart = repeatOptional ":" ipv6Block rightNum;
        in
        "${leftPart}:${middlePart}:${rightPart}";
      genAll = max: builtins.genList (genVariant max) max;
      normals = genAll 8;
      ipv4Mapped = map (x: "${x}:${ipv4Addr}") (genAll 6);
    in
    concatGroup (normals ++ ipv4Mapped);
  v4CIDR = "/(3[0-2]|2[0-9]|1?[0-9])";
  v6CIDR = "/(12[0-8]|1[0-2][0-9]|[1-9]?[0-9])";
  # TODO restrict more according to https://www.freedesktop.org/software/systemd/man/latest/systemd.link.html#Name=
  interfaceName = "[^:/%]{0,15}";
  interfaceId = "(%${interfaceName})?";
  # === references
  ipv6Ref = "RFC 4291 Section 2.2";
in
# extensions to the nix option types library
{

  disectComposed =
    typ:
    let
      disectable = [
        "attrsOf"
        "lazyAttrsOf"
        "listOf"
      ];
    in
    if lib.types.isOptionType typ then
      if elem typ.name disectable then
        {
          type = typ.name;
          recreate = lib.types.${typ.name};
          value = typ.nestedTypes.elemType;
        }
      else
        {
          type = "direct";
          recreate = (x: x);
          value = typ;
        }
    else
      {
        type = "unknown";
        recreate = throw "unknown type to extract submodule from, hence no recreate";
        value = typ;
      };

  subCombined =
    # TODO reuse submodule typeMerge
    # TODO replace .getSubModules everywhere somehow with this
    subMods:
    let
      extractOption = subM: if lib.options.isOption subM then subM.type else subM;
      extractModules =
        subM:
        if lib.types.isOptionType subM then
          assert subM.name == "submodule";
          subM.getSubModules
        else
          lib.lists.singleton subM;
    in
    lib.types.submodule {
      imports = pipe subMods [
        toList
        (map (
          flip pipe [
            extractOption
            (x: (self.disectComposed x).value)
            extractModules
          ]
        ))
        concatLists
      ];
    };

  extendsSubmodule =
    opt:
    let
      type = if lib.isOption opt then opt.type else opt;
      disected = self.disectComposed type;
      sub = disected.value;
    in
    assert lib.types.isOptionType type;
    assert lib.types.isOptionType sub && sub.name == "submodule";
    arg: disected.recreate (self.subCombined (sub.getSubModules ++ [ arg ]));

  eui48 = matchType {
    description = "EUI-48 (i.e. MAC address)";
    pattern = eui48;
  };

  eui64 = matchType {
    description = "EUI-64";
    pattern = eui64;
  };

  ifName = matchType {
    description = "UNIX interface name";
    pattern = interfaceName;
  };

  ipAddress = lib.types.either self.ipv4Address self.ipv6Address;

  ipAddressPlain = lib.types.either self.ipv4AddressPlain self.ipv6AddressPlain;

  ipNetwork = lib.types.either self.ipv4Network self.ipv6Network;

  ipv4Address = matchType {
    description = "IPv4 address (no CIDR, opt. interface identifier)";
    pattern = ipv4Addr + interfaceId;
  };

  ipv4AddressPlain = matchType {
    description = "IPv4 address (no CIDR, no interface identifier)";
    pattern = ipv4Addr;
  };

  ipv4Network = matchType {
    description = "IPv4 address/network with CIDR";
    pattern = ipv4Addr + v4CIDR;
  };

  ipv6IfId = matchType {
    description = "IPv6 interface identifier (64-bit hex suffix)";
    # TODO maybe allow IPv4 suffix
    pattern = concatGroup [
      (concatRepeat ":" ipv6Block 4)
      (":${repeatOptional ":" ipv6Block 3}")
    ];
  };

  ipv6Address = matchType {
    description = "IPv6 address (${ipv6Ref}, no CIDR, opt. interface identifier)";
    pattern = ipv6Addr + interfaceId;
  };

  ipv6AddressPlain = matchType {
    description = "IPv6 address (${ipv6Ref}, no CIDR, no interface identifier)";
    pattern = ipv6Addr;
  };

  ipv6Network = matchType {
    description = "IPv6 address/network with CIDR (${ipv6Ref})";
    pattern = ipv6Addr + v6CIDR;
  };

}
