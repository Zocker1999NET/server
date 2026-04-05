{ lib, self, ... }@flakeArg:
# TODO (improvement) check how much of this is obsolete, see nixpkgs#lib.network.ipv6
let
  inherit (builtins)
    concatMap
    concatStringsSep
    mapAttrs
    elemAt
    genList
    isAttrs
    length
    match
    replaceStrings
    stringLength
    ;
  inherit (lib.asserts) assertMsg;
  inherit (lib.lists)
    count
    imap1
    last
    singleton
    sublist
    ;
  # TODO (improvement) check if lib.trivial.toBaseDigits is more performant
  inherit (lib.math) binToInt intToBin;
  inherit (lib.strings)
    commonPrefixLength
    hasInfix
    splitString
    substring
    toIntBase10
    toLower
    ;
  inherit (lib.trivial)
    flip
    fromHexString
    pipe
    toHexString
    ;
  # TODO export via lib.strings
  fixedWidthStrSuffix =
    width: filler: str:
    let
      strw = lib.stringLength str;
      reqWidth = width - (lib.stringLength filler);
    in
    assert lib.assertMsg (strw <= width)
      "fixedWidthString: requested string length (${toString width}) must not be shorter than actual length (${toString strw})";
    if strw == width then str else fixedWidthStrSuffix reqWidth filler str + filler;
  toHex = str: toLower (toHexString str);
  ipClassStatics = {
    ipv4 = {
      _group_bits = 8;
      _group_count = 4;
      _group_sep = ".";
      _group_toInt = toIntBase10;
    };
    ipv6 = {
      _group_bits = 16;
      _group_count = 8;
      _group_sep = ":";
      _group_toInt = fromHexString;
    };
  };
  toIpClass =
    ipArg:
    let
      roles = {
        ipv4 = {
          compressed = ip.decCompressed;
          shorted = ip.decCompressed;
        };
        ipv6 = {
          compressed = ip.hexShorted; # TODO temporary
          shorted = ip.hexShorted;
        };
      };
      ip =
        ipClassStatics.${ipArg.version} # avoid recursion error
        // roles.${ipArg.version} # avoid recursion error
        // {
          type = "ipAddress";
          # internal operators
          __toString = s: s.cidrCompressed;
          # decimal
          decGroups = map ip._group_toInt ip._groups;
          decCompressed = concatStringsSep ip._group_sep (map toString ip.decGroups);
          # binary
          binGroups = map (intToBin ip._group_bits) ip.decGroups; # shortcut compared to hexGroups
          binRaw = concatStringsSep "" ip.binGroups;
          # hex
          hexGroups = map toHex ip.decGroups;
          hexShorted = concatStringsSep ":" ip.hexGroups;
          # TODO hexCompressed
          # TODO hexExploded
          # network
          binRawNet = substring 0 ip.cidrInt ip.binRaw;
          network = self.parseBinNet ip.version ip.binRawNet;
          _cidr_max = ip._group_count * ip._group_bits;
          cidrInt = if ip._cidrGroup == null then ip._cidr_max else toIntBase10 ip._cidrGroup;
          cidrCompressed = "${ip.compressed}/${ip.cidrStr}";
          cidrShorted = "${ip.shorted}/${ip.cidrStr}";
          cidrStr = "${toString ip.cidrInt}";
          # helpers
          isCompatible =
            o:
            assert self.isParsedIP o;
            ip.type == o.type;
          __verifyCompat = fun: o: if ip.isCompatible o then fun o else false;
          split = map (self.parseBinNet ip.version) [
            "${ip.binRawNet}0"
            "${ip.binRawNet}1"
          ];
        }
        // mapAttrs (_: ip.__verifyCompat) {
          contains = o: ip.cidrInt <= commonPrefixLength ip.binRawNet (o.binRawNet);
          equals = o: ip.decGroups == o.decGroups && ip.cidrInt == o.cidrInt;
          sameNetwork = o: ip.binRawNet == o.binRawNet;
        }
        // ipArg;
    in
    assert assertMsg (length ip._groups == ip._group_count)
      "invalid IP group count, expected ${toString ip._group_count}, got: ${toString (length ip._groups)}, input: ${ipArg._input} (bug, please report)";
    assert ip.cidrInt <= ip._cidr_max;
    ip;
in
rec {

  formatMAC =
    let
      badChars = [
        "."
        ":"
        "_"
        "-"
      ];
      goodChars = map (x: "") badChars;
    in
    mac:
    pipe mac [
      (replaceStrings badChars goodChars)
      toLower
    ];

  isParsedIP = x: isAttrs x && x.type or null == "ipAddress";
  isParsedIPv4 = x: isParsedIP x && x.version == "ipv4";
  isParsedIPv6 = x: isParsedIP x && x.version == "ipv6";

  parseIP = ip: if hasInfix ":" ip then parseIPv6 ip else parseIPv4 ip;

  parseIPv4 =
    ipStr:
    let
      parsed = match ''^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)(/([0-9]+))?$'' ipStr;
      ip = toIpClass {
        version = "ipv4";
        _input = ipStr;
        _cidrGroup = last parsed;
        _groups = sublist 0 4 parsed;
      };
    in
    assert parsed != null; # TODO improve
    ip;

  parseIPv6 =
    # TODO add support for IPv4 mapped addresses
    ipStr:
    let
      parsed = match "^(([0-9a-f]{0,4}:){1,7}[0-9a-f]{0,4})(/([0-9]+))?$" (toLower ipStr);
      rawGroups = pipe parsed [
        (flip elemAt 0)
        (splitString ":")
        # first & last zeros might be omitted as well, but are not a compression artifact
        (imap1 (i: x: if (i == 1 || i == length rawGroups) && x == "" then "0" else x))
      ];
      groups = flip concatMap rawGroups (
        x: if x == "" then genList (_: "0") (9 - length rawGroups) else singleton x
      );
      ip = toIpClass {
        version = "ipv6";
        _input = ipStr;
        _cidrGroup = last parsed;
        _groups = groups;
      };
    in
    assert parsed != null;
    assert count (g: g == "") rawGroups <= 1;
    ip;

  parseIPv6IfId =
    ipStr:
    let
      parsed = match "^(([0-9a-f]{0,4}:){1,3}[0-9a-f]{0,4})$" (toLower ipStr);
      rawGroups = pipe parsed [
        (flip elemAt 0)
        (splitString ":")
        # first & last zeros might be omitted as well, but are not a compression artifact
        (imap1 (i: x: if (i == 1 || i == length rawGroups) && x == "" then "0" else x))
      ];
      groups = flip concatMap rawGroups (
        x: if x == "" then genList (_: "0") (5 - length rawGroups) else singleton x
      );
      ip = toIpClass {
        type = "ipInterfaceIdentifier";
        version = "ipv6";
        _group_count = 4;
        _input = ipStr;
        _cidrGroup = null;
        _groups = groups;
      };
    in
    assert parsed != null;
    assert count (g: g == "") rawGroups <= 1;
    ip;

  parseBinNet =
    ipV: binStr:
    let
      _group_count = ipClassStatics.${ipV}._group_count;
      ip = toIpClass {
        version = ipV;
        _input = binStr;
        # special overwrites - TODO integrate into toIpClass
        cidrInt = stringLength binStr;
        binRaw = fixedWidthStrSuffix ip._cidr_max "0" binStr;
        binGroups = genList (i: substring (ip._group_bits * i) ip._group_bits ip.binRaw) ip._group_count;
        decGroups = map binToInt ip.binGroups;
        # decoy for asserts
        _groups = genList (i: throw "_groups values not available for parseBinNet") _group_count;
        # shortcuts
        binRawNet = binStr;
      };
    in
    ip;

  mergeIPv6IfId =
    prefix: suffix:
    let
      pref = parseIPv6 prefix;
      suff = parseIPv6IfId suffix;
    in
    assert pref.cidrInt <= 64;
    "${concatStringsSep ":" (sublist 0 4 pref.hexGroups ++ suff.hexGroups)}/64";

  netMinus =
    excl: net:
    if net.sameNetwork excl then
      [ ]
    else if !net.contains excl then
      singleton net
    else
      net.split;

  netListMinus = excl: concatMap (netMinus excl);

}
