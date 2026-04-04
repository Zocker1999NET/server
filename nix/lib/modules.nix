{ inputs, lib, ... }@flakeArg:
let
  inherit (builtins)
    isAttrs
    isBool
    isPath
    isString
    ;
  inherit (lib) types;
  inherit (lib.attrsets)
    attrByPath
    optionalAttrs
    setAttrByPath
    ;
  inherit (lib.lists) foldl optional;
  inherit (lib.modules)
    applyOnDefinition
    defaultOverridePriority
    defaultOrderPriority
    dischargeValue
    importApply
    importsApplyIf
    mergeDefinitions
    mkAliasIfDef
    mkFullAlias
    mkIf
    mkMerge
    mkOverride
    mkOrder
    ;
  inherit (lib.options) mkOption showFiles showOption;
  inherit (lib.trivial) id;

  # internal helpers
  applyOnValue = apply: { value, ... }@attr: attr // { value = apply value; };
in
{

  applyOnDefinition =
    apply: loc: type:
    # only "discharge" when required to reduce required calculations
    if apply == null then id else applyOnValue (v: apply (dischargeValue loc type v));

  dischargeValue =
    loc: type: value:
    mergeDefinitions loc type [ value ];

  # TODO upstream
  importsApplyIf = staticArg: map (i: if isPath i || isString i then importApply i staticArg else i);

  # TODO upstream
  mkFullAlias =
    {
      loc,
      option,
      apply ? null,
      wrap ? id,
      keepOverridePriority ? true,
      keepOrderPriority ? true,
    }:
    let
      prio = option.highestPrio or defaultOverridePriority;
      # lazy implementation, see https://github.com/NixOS/nix/issues/15625
      pipe = foldl (x: f: f x);
    in
    pipe option [
      (opt: opt.definitionsWithLocations)
      (map (applyOnDefinition apply loc option.type))
      (map (
        if keepOrderPriority then
          (def: mkOrder (def.priority or defaultOrderPriority) def.value)
        else
          (def: def.value)
      ))
      (if keepOverridePriority then map (mkOverride prio) else id)
      mkMerge
      wrap
      (mkAliasIfDef option)
    ];

  # TODO upstream
  mkFullAliasModule =
    {
      # List of strings representing the attribute path of the old option.
      from,
      # List of strings representing the attribute path of the new option.
      to,
      # Whether an alias option for from should be declare. May also be an attr to supplement its definition.
      declareFrom ? false,
      # Whether to warn when a value is defined for the old option.
      warn ? false,
      # Function that is applied to the option value to form the value of the old `from` option
      use ? id,
      # Function that is applied to the option value to form the value of the new `to` option.
      apply ? null,
      # Whether to preserve the priorities of definitions in `old`, enabled by default.
      keepOrderPriority ? true,
      keepOverridePriority ? true,
      # A boolean that defines the `mkIf` condition for `to`, defaults to true.
      condition ? true,
    }:
    { config, options, ... }:
    let
      # help functions
      msg_optMissing = opt: abort "Alias error: option `${showOption opt}` does not exist.";
      loadOptFrom = opt: attr: attrByPath opt (msg_optMissing opt) attr;
      # help vars
      msg_warning = "The option `${showOption from}' defined in ${showFiles fromOpt.files} has been migrated to `${showOption to}'.";
      fromDeclare = isAttrs declareFrom || (isBool declareFrom && declareFrom);
      fromOpt = loadOptFrom from options;
      toOf = loadOptFrom to;
      toType =
        let
          opt = attrByPath to { } options;
        in
        opt.type or (types.submodule { });
    in
    {
      options = optionalAttrs fromDeclare (
        setAttrByPath from (
          mkOption {
            description = "Alias of {option}`${showOption to}`.";
            apply = x: use (toOf config);
          }
          // optionalAttrs (toType != null) {
            type = toType;
          }
          // optionalAttrs (isAttrs declareFrom) declareFrom
        )
      );
      config = mkIf condition (mkMerge [
        (optionalAttrs (options ? warnings) {
          warnings = optional (warn && fromOpt.isDefined) msg_warning;
        })
        (mkFullAlias {
          loc = from;
          option = fromOpt;
          wrap = setAttrByPath to;
          inherit apply keepOverridePriority keepOrderPriority;
        })
      ]);
    };

  importApplyMod = path: importApply path flakeArg;
  importsApplyMods = importsApplyIf flakeArg;

  # TODO upstream
  mkTestOverride = mkOverride 55;

}
