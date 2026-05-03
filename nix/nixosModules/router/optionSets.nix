{ lib, libBNet, ... }@globalArg:
let
  # === helpers
  inherit (builtins)
    all
    attrNames
    attrValues
    concatLists
    concatMap
    elem
    filter
    intersectAttrs
    isAttrs
    isString
    mapAttrs
    removeAttrs
    ;
  inherit (lib)
    mapAttrsJoin
    nftablesReference
    protoType
    ;
  inherit (libBNet) types;
  inherit (lib.attrsets) filterAttrs mergeAttrsList optionalAttrs;
  inherit (lib.lists) singleton toList;
  inherit (lib.modules)
    evalModules
    mkIf
    mkOverride
    setDefaultModuleLocation
    ;
  inherit (libBNet.network) formatMAC;
  inherit (lib.options) isOption mkOption;
  inherit (lib.strings) hasPrefix;
  inherit (lib.trivial) flip pipe warn;
  inherit (types) extendsSubmodule isOptionType subCombined;
  # just for better error messages
  submodule = mod: types.submodule (setDefaultModuleLocation ./optionSets.nix mod);
  getOpts =
    mod:
    assert isAttrs mod;
    assert isOptionType mod;
    assert (mod.name or null) == "submodule";
    # TODO (maybe) reuse type value evalution
    (evalModules { modules = mod.getSubModules; }).options;
  mkListOptionOf =
    { original, ... }@args:
    let
      opt = original;
    in
    assert isOption opt;
    mkOption (mergeAttrsList [
      (optionalAttrs (opt ? default) { default = singleton opt.default; })
      (optionalAttrs (opt ? defaultText) {
        defaultText =
          # TODO support more if required, nothing else supported yet
          assert isAttrs opt.defaultText && opt.defaultText.type == "literalExpression";
          lib.literalExpression "[ ${opt.defaultText} ]";
      })
      (optionalAttrs (opt ? example) {
        example =
          # TODO add support for more (test before if literal… are here even allowed)
          assert (isAttrs opt.example && opt.example ? type) -> opt.example.type != "literalExpression";
          singleton opt.example;
      })
      {
        description = "List variant of: " + opt.description;
        type = types.listOf opt.type;
      }
      (removeAttrs args (singleton "original"))
    ]);
  # "replaces" all options of given `mod` with a plural/listOf variant of option `single`
  listVariantSubmodule =
    {
      single,
      plural ? "${single}s",
      module,
      optionArgs ? { },
      inputFilter ? [ ],
      outputFilter ? [ ],
    }:
    let
      modKey = "${keyPref}.listVariantSubmodule.${single}";
      ruleOpt = "_${plural}AllRules";
      modOpts = getOpts module;
      opt = modOpts.${single};
    in
    submodule (
      {
        config,
        options,
        extendModules,
        moduleType,
        name,
        ...
      }:
      let
        refine = attrs: val: removeAttrs attrs (singleton plural) // { ${single} = val; };
        modType =
          (extendModules {
            modules = module.getSubModules ++ [
              {
                key = "${modKey}.fakePlural";
                disabledModules = singleton { key = modKey; };
                options.${plural} = mkOption {
                  # "fake" option to catch split values
                  internal = true;
                  type = types.addCheck types.raw (
                    x:
                    warn "option ${plural} is accessed after splitting up rules, this should normally not happen" true
                  );
                };
              }
              # workaround weird issue of multiple name definitions, no idea why that happens, but it is still a good idea to import that really explicitly
              {
                key = "${keyPref}.copyName"; # can be deduplicated across different listVariant resolves
                config._module.args.name = mkOverride 0 single;
              }
            ];
          }).type;
        ourOpts = {
          ${plural} = mkListOptionOf (optionArgs // { original = opt; });
          ${ruleOpt} = mkOption {
            internal = true;
            readOnly = true;
            type = types.listOf modType;
            default = pipe config (concatLists [
              inputFilter
              [ (cfg: map (refine (cfg._clone)) config.${plural}) ]
              outputFilter
            ]);
          };
        };
      in
      {
        key = modKey;
        config =
          # TODO convert to modules=
          assert lib.assertMsg (options ? _clone) "listVariant requires cloneRule to be loaded";
          assert lib.assertMsg (options ? _multiRules) "listVariant requires multiRule to be loaded";
          # this cannot be in disabledModules, because otherwise ruleOpt would missing the singular option as well
          assert !(options ? ${single}); # incompatible with single option in the same module
          {
            _cloneNot = [ ruleOpt ];
            _cloneTargetAvoid = singleton single;
            _multiResolveFilter.${single} = x: x.${ruleOpt};
          };
        options = ourOpts;
      }
    );
  # === statics
  keyPref = "work.banananet.nixos.router.optionSets";
  ipVersions = [
    "ipv4"
    "ipv6"
  ];
in
# all rules assume being applied in the context of a incoming interface
rec {

  # expose here for convient use
  inherit subCombined;

  # actual rules

  cloneRule = submodule (
    { config, options, ... }:
    let
      # avoid unexpected list mergings
      centerPrio = 253; # >100, <1000, unlikely to use by hand
      modifyPrio = prio: if prio < centerPrio then prio + 1 else prio - 1;
      cloneOpt = o: mkOverride (modifyPrio o.highestPrio) o.value;
      clonedOpts = filterAttrs (
        n: o:
        all (x: x) [
          (!hasPrefix "_" n)
          (!elem n config._cloneNot)
          (o.isDefined)
          (!o.readOnly or false) # cloning not with readOnly attributes compatible
        ]
      ) options;
    in
    {
      key = "${keyPref}.cloneRule";
      options = {
        # in
        _cloneNot = mkOption {
          internal = true;
          type = with types; listOf str;
          default = [ ];
        };
        _cloneTargetAvoid = mkOption {
          description = "options which the _cloneFor target MUST NOT have (detect ambiguity because of listVariants)";
          internal = true;
          type = with types; listOf str;
          default = [ ];
        };
        # out
        _clone = mkOption {
          internal = true;
          readOnly = true;
          default = mapAttrs (_: cloneOpt) clonedOpts;
        };
        _cloneValues = mkOption {
          internal = true;
          readOnly = true;
          default = mapAttrs (_: o: o.value) clonedOpts;
        };
        _cloneFor = mkOption {
          internal = true;
          readOnly = true;
          default =
            target:
            let
              origType = if isOption target then target.type else target;
              subM = (types.disectComposed origType).value;
              compatible = subM.getSubOptions [ "_CLONE" ];
            in
            assert isOptionType subM && subM.name == "submodule";
            assert all (n: !compatible ? n) config._cloneTargetAvoid;
            intersectAttrs compatible config._clone;
        };
      };
      config._cloneNot = filter (hasPrefix "_") (attrNames options);
    }
  );
  multiRule = submodule (
    { config, ... }:
    let
      combinedFilter = flip pipe (concatLists [
        config._multiInputFilter
        [ toList ] # because in next step, lists will come out
        (map concatMap (attrValues config._multiResolveFilter))
        config._multiOutputFilter
      ]);
    in
    {
      key = "${keyPref}.multiRule";
      options = {
        _multiInputFilter = mkOption {
          internal = true;
          # … -> …
          type = with types; listOf raw;
          default = [ ];
        };
        _multiResolveFilter = mkOption {
          internal = true;
          # … -> [ … ]
          type = with types; attrsOf raw;
          default = { };
        };
        _multiOutputFilter = mkOption {
          internal = true;
          # [ … ] -> [ … ]
          type = with types; listOf raw;
          default = [ ];
        };
        # out
        _multiRules = mkOption {
          internal = true;
          readOnly = true;
          default = combinedFilter config;
        };
      };
    }
  );
  defaultRules = subCombined [
    cloneRule
    multiRule
  ];

  commentRule = submodule {
    key = "${keyPref}.commentRule";
    options.comment = mkOption {
      description = "Comment for this rule";
      type = types.str;
    };
  };
  commentRuleName = extendsSubmodule commentRule (
    { name, ... }:
    {
      key = "${keyPref}.commentRuleName";
      options.comment = mkOption { default = name; };
    }
  );

  enableRule = submodule {
    key = "${keyPref}.enableRule";
    options.enable = lib.mkDisableOption "this rule";
  };

  ipRule = submodule {
    key = "${keyPref}.ipRule";
    options = {
      # TODO auto-determine on sources
      ipVersion = mkOption {
        description = "IP version this rule applies to";
        type = types.uniq (types.enum ipVersions);
      };
    };
  };
  multiIpRule = listVariantSubmodule {
    single = "ipVersion";
    module = ipRule;
    optionArgs = {
      default = ipVersions; # for all
    };
    # TODO filter IPs in other options
  };

  sourceRule = submodule (
    let
      sourceType = with types; either ipNetwork nftablesReference;
      resolveDefined = attrs: value: if isString value && attrs ? ${value} then attrs.${value} else value;
      ipRanges = {
        all = {
          ipv4 = "0.0.0.0/0";
          ipv6 = "::/0";
        };
        localhost = {
          ipv4 = "127.0.0.0/8";
          ipv6 = "::1/128";
        };
        ula = rec {
          desc = "IPv6 Unique Link Locals (${ipv6})";
          ipv4 = abort "IPv4 has no unique link local addresses";
          ipv6 = "fc00::/7";
        };
        network = rec {
          desc = "connections incoming from the incoming interface’s subnets";
          ipv4 = abort "special case 'network' must be catched outside of this submodule (bug in module, please report)";
          ipv6 = ipv4;
        };
      };
    in
    { ... }@source:
    let
      cfg = source.config;
      opts = source.options;
      ranges = mapAttrs (_: x: x.${cfg.ipVersion}) ipRanges;
      resolved = resolveDefined ranges cfg.source;
    in
    {
      key = "${keyPref}.sourceRule";
      options = {
        source = mkOption {
          description = ''
            Source need to match for this rule.

            Following values are possible:
            ${mapAttrsJoin "" ipRanges (
              name: v:
              let
                desc = if v ? desc then ": ${v.desc}" else " = IPv4: ${v.ipv4} / IPv6: ${v.ipv6}";
              in
              ''
                - `"${name}"`${desc}
              ''
            )}
            - reference to nftables set (`@<set>`)
            - hardcoded IP network (using CIDR format)
          '';
          type = types.either sourceType (types.enum (attrNames ipRanges));
          default = "all";
          example = "10.12.34.0/26";
        };
        sourceIP = mkOption {
          internal = true;
          readOnly = true;
          type = sourceType;
          default = resolved;
        };
      };
      config = intersectAttrs opts { _cloneNot = singleton "sourceIP"; };
    }
  );
  multiSourceRule = listVariantSubmodule {
    single = "source";
    module = sourceRule;
    inputFilter = [
      # optional shortcut: kill other sources if all is given
      (cfg: cfg // optionalAttrs (elem "all" cfg.sources) { sources = singleton "all"; })
    ];
  };

  # no multi & no special values because this might be used for DNAT rules
  destinationRule = submodule {
    key = "${keyPref}.destinationRule";
    options = {
      destination = mkOption {
        description = ''
          Destination for which this rule applies.

          Device MAC needs to be listed in `ifCfg.devices`.
        '';
        type = with types; either ipAddressPlain nftablesReference;
        example = "";
      };
    };
  };

  deviceRule = extendsSubmodule destinationRule (
    { ... }@dev:
    let
      cfg = dev.config;
      opts = dev.options;
    in
    {
      key = "${keyPref}.deviceRule";
      options = {
        device = mkOption {
          description = ''
            Destination device for which this rule applies.

            Device MAC should to be listed in `ifCfg.devices`.
          '';
          type = types.eui48;
          example = "AA:BB:CC:DD:EE:FF";
        };
        dynamicDestination = mkOption {
          internal = true;
          readOnly = true;
          default =
            if cfg.ipVersion == "ipv6" then
              "$ipv6_${cfg.downstream}_${formatMAC cfg.device}"
            else
              cfg.destination;
        };
        downstream = mkOption {
          description = "downstream interface, where the device address is from";
          type = lib.types.str;
          # default defined by user
        };
      };
      # MUST be option default to avoid cloning that attr
      config = intersectAttrs opts {
        _cloneNot = [
          "destination"
          "dynamicDestination"
        ];
        destination = mkIf opts.device.isDefined (
          if cfg.ipVersion == "ipv4" then
            globalArg.cfg.interfaces.${cfg.downstream}.references.macToIPv4.${formatMAC cfg.device}
          else if cfg.ipVersion == "ipv6" then
            abort "Cannot get static destination for IPv6 (use dynamicDestination instead)"
          else
            abort "invalid IP version ${cfg.ipVersion}"
        );
      };
    }
  );
  multiDeviceRule = listVariantSubmodule {
    single = "device";
    module = deviceRule;
  };

  protoRule = submodule {
    key = "${keyPref}.protoRule";
    options = {
      protocol = mkOption {
        description = "Protocol for which this port rule applies to";
        type = protoType;
        default = "tcp";
      };
    };
  };

  portRule = extendsSubmodule protoRule {
    key = "${keyPref}.portRule";
    options = {
      port = lib.mkOption {
        description = "Destination port this rule applies to";
        type = lib.types.port;
      };
    };
  };

  # litte bit hacky "workaround" for getting full & port rules nicely alligned
  # needs to declare same options as portRule
  protoWildcardRule = submodule {
    key = "${keyPref}.protoWildcardRule";
    options = {
      protocol = mkOption {
        internal = true;
        description = "Protocol for which this port rule applies to";
        default = "0/0";
      };
      port = lib.mkOption {
        internal = true;
        description = "Destination port this rule applies to";
        default = "0/0";
      };
    };
  };

  dnatRule = extendsSubmodule protoRule (
    { config, ... }:
    {
      key = "${keyPref}.dnatRule";
      options = {
        wanPort = lib.mkOption {
          description = "port on the WAN side";
          type = lib.types.port;
          default = config.lanPort;
          defaultText = lib.literalExpression "cfg.lanPort";
          example = 8080;
        };
        lanPort = lib.mkOption {
          description = "port on the LAN side";
          type = lib.types.port;
          example = 80;
        };
      };
    }
  );

  exposeRule = submodule {
    key = "${keyPref}.exposeRule";
    options.expose = mkOption {
      description = "Enables exposure of {option}`lanPort` directly via IPv6";
      type = types.bool;
      # no default declared here -> importer can declare default
    };
  };

  pingableRule = submodule {
    key = "${keyPref}.pingableRule";
    options.pingable = lib.mkOption {
      description = ''
        Whether to make a device with this port rule pingable for the declared sources.
      '';
      type = types.bool;
      # no default declared here -> importer can declare default
    };
  };
}
