{ config, lib, ... }:
let
  cfg = config.networking.nftables.marks;
  inherit (builtins)
    attrNames
    attrValues
    bitAnd
    bitOr
    concatMap
    concatStringsSep
    elemAt
    filter
    foldl'
    length
    listToAttrs
    ;
  inherit (lib) types;
  inherit (lib.attrsets)
    attrsToList
    filterAttrs
    mapCartesianProduct
    nameValuePair
    optionalAttrs
    ;
  inherit (lib.lists)
    findFirstIndex
    imap1
    singleton
    range
    ;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) flip pipe;
  mkHelper =
    args:
    mkOption (
      args
      // {
        readOnly = true;
        type = types.str;
      }
    );
  powers =
    base:
    (foldl'
      (acc: _: rec {
        last = acc.last * base;
        result = acc.result ++ singleton last;
      })
      {
        last = 1;
        result = [ 1 ];
      }
      (range 0 (markMaxNum - 1))
    ).result;
  pow = base: elemAt (powers base);
  logUpper =
    base: v:
    if v <= 0 then
      abort "unsupported to get log_2 of non-positive number ${v}"
    else
      findFirstIndex (r: v <= r) markMaxNum (powers base);
  markCommon =
    { ... }@mark:
    let
      c = mark.config;
    in
    {
      options = {
        # properties
        domain = mkOption {
          description = "all apply to both meta & ct marks (at least for now)";
          type = types.enum [ "meta+ct" ];
          readOnly = true;
          default = "meta+ct";
        };
        name = mkOption { type = types.str; };
        # values
        bitmaskInt = mkOption { type = types.ints.u32; };
        # TODO (security) check if nftables uses unsigned numbers
        bitmaskSize = mkOption { type = types.ints.between 0 markMaxNum; };
        bitmask = mkHelper { default = toString c.bitmaskInt; };
        bitmaskNeg = mkHelper { default = toString (markMaxVal - c.bitmaskInt); };
        # packet values
        metaValue = mkHelper { default = "meta mark & ${c.bitmask}"; };
        ctValue = mkHelper { default = "ct mark & ${c.bitmask}"; };
        metaOtherValue = mkHelper { default = "meta mark & ${c.bitmaskNeg}"; };
        ctOtherValue = mkHelper { default = "ct mark & ${c.bitmaskNeg}"; };
        # group checks
        metaIsAnySet = mkHelper { default = "${c.metaValue} != 0"; };
        ctIsAnySet = mkHelper { default = "${c.ctValue} != 0"; };
        metaIsAllUnset = mkHelper { default = "${c.metaValue} == 0"; };
        ctIsAllUnset = mkHelper { default = "${c.ctValue} == 0"; };
        # unset
        metaUnset = mkHelper { default = "meta mark set ${c.metaOtherValue}"; };
        ctUnset = mkHelper { default = "ct mark set (${c.ctOtherValue})"; };
        # copy
        metaToCt = mkHelper { default = "ct mark set (${c.ctOtherValue}) | (${c.metaValue})"; };
        ctToMeta = mkHelper { default = "meta mark set (${c.metaOtherValue}) | (${c.ctValue})"; };
      };
    };
  markGroupType = types.submodule {
    freeformType = types.attrsOf markValueType;
    imports = singleton markCommon;
  };
  markValueType = types.submodule (
    { ... }@mark:
    let
      c = mark.config;
    in
    {
      imports = singleton markCommon;
      options = {
        # properties
        group = mkOption { type = types.nullOr types.str; };
        # values
        valueInt = mkOption { type = types.ints.u32; };
        value = mkHelper { default = toString c.valueInt; };
        # value checks
        metaIsSet = mkHelper { default = "${c.metaValue} == ${c.value}"; };
        ctIsSet = mkHelper { default = "${c.ctValue} == ${c.value}"; };
        metaIsNotSet = mkHelper { default = "${c.metaValue} != ${c.value}"; };
        ctIsNotSet = mkHelper { default = "${c.ctValue} != ${c.value}"; };
        # set
        metaSet = mkHelper { default = "meta mark set (${c.metaOtherValue}) | ${c.value}"; };
        ctSet = mkHelper { default = "ct mark set (${c.ctOtherValue}) | ${c.value}"; };
      };
    }
  );
  invalidGroupNames = attrNames (markCommon { }).options;
  groups = filterAttrs (_: x: x != null) cfg.groups;
  values = attrValues cfg.values;
  # as supported by nftables / netfilter
  markMaxNum = 32;
  markMaxVal = 4294967296;
in
assert logUpper 2 markMaxVal == 32;
{

  _class = "nixos";

  options.networking.nftables.marks = {
    groups = mkOption {
      description = ''
        List of nftables mark groups which values should be assigned non-overlapping.

        An unset state is implicitly added,
        hence a group with 4 members needs a 3 bit bitmask.
        Groups without explicit members are considered single flags
        with two states (set & unset).

        Note: Do not mix this with other approaches of managing nftables marks (e.g. manual management),
        otherwise if overlapping values are used,
        unintended side affects may happen.

        Some terms cannot be used as group member names due to implementation reasons,
        as they are used to to provide group helpers in {option}`networking.nftables.marks.values`,
        these are: ${toString invalidGroupNames}.
      '';
      # If you need so, use one of the other options to avoid overlapping mark values (TODO introduce these options).
      type = with types; attrsOf (nullOr (listOf str));
      default = { };
      example = {
        sourceClass = [
          "vpn"
          "internal"
          "external"
        ];
        flaggedTraffic = [ ];
      };
    };
    # output
    values = mkOption {
      readOnly = true;
      description = ''
        Output option giving access to the values chosen for the given marks & matching helpers.

        TODO more docu on how to use
      '';
      type = with types; attrsOf (either (types.addCheck markValueType (x: x ? group)) markGroupType);
    };
  };

  config = {
    assertions = [
      (
        let
          groupDescs = flip map values (g: "  - group ${g.name}: ${toString g.bitmaskSize} bits");
          sum = foldl' (a: g: a + g.bitmaskSize) 0 (attrValues cfg.values);
        in
        {
          assertion = sum <= markMaxNum;
          message = concatStringsSep "\n" (
            singleton "nftables marks require ${toString sum} bits, more than the ${toString markMaxNum} bits suppported by netfilter"
            ++ groupDescs
          );
        }
      )
      (
        # as safety gurantee
        let
          overlapping = pipe values [
            (m: {
              left = m;
              right = m;
            })
            (mapCartesianProduct (
              { left, right }@attrs:
              if left.name != right.name && bitAnd left.bitmaskInt right.bitmaskInt != 0 then attrs else null
            ))
            (filter (x: x != null))
            (concatMap (x: [
              x.left
              x.right
            ]))
          ];
        in
        {
          assertion = overlapping == [ ];
          message = concatStringsSep "\n" (
            singleton "some calculated mark bitmasks are overlapping (bug in module, please report)"
            ++ map (x: "  - group ${x.name}: bitmask ${x.bitmask}") overlapping
          );
        }
      )
      # following are already prevented by the module system, but the error message might be not useful
      (
        let
          invalids = filter (name: groups ? name) invalidGroupNames;
        in
        {
          assertion = invalids == [ ];
          message = "Some group names are reserved and cannot be used: " + toString invalids;
        }
      )
    ];

    networking.nftables.marks.values = pipe groups [
      attrsToList
      (foldl'
        (
          { blocked, result }:
          { name, value }:
          let
            offset = blocked + 1;
            states = (if value == [ ] then 1 else length value) + 1;
            bitmaskSize = logUpper 2 states;
            bitmaskInt = offset * (pow 2 bitmaskSize - 1);
          in
          {
            blocked = bitOr bitmaskInt blocked;
            result =
              result
              ++ singleton {
                inherit
                  name
                  offset
                  bitmaskSize
                  bitmaskInt
                  ;
                members = value;
              };
          }
        )
        {
          blocked = 0;
          result = [ ];
        }
      )
      (
        x:
        assert x.blocked < markMaxVal;
        x.result
      )
      (map (
        {
          name,
          members,
          offset,
          bitmaskInt,
          bitmaskSize,
        }:
        nameValuePair name (
          {
            inherit name bitmaskSize bitmaskInt;
          }
          // optionalAttrs (members == [ ]) {
            group = null;
            valueInt = bitmaskInt;
          }
          // pipe members [
            (imap1 (
              i: m:
              let
                valueInt = offset * i;
              in
              assert bitOr bitmaskInt valueInt == bitmaskInt;
              {
                name = m;
                value = {
                  group = name;
                  name = m;
                  inherit bitmaskSize bitmaskInt valueInt;
                };
              }
            ))
            listToAttrs
          ]
        )
      ))
      listToAttrs
    ];
  };

}
