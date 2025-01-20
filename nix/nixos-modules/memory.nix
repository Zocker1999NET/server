{
  config,
  lib,
  options,
  ...
}:
let
  inherit (builtins)
    concatLists
    concatMap
    concatStringsSep
    foldl'
    head
    ;
  inherit (lib) types;
  inherit (lib.attrsets)
    getAttrFromPath
    mapAttrsToList
    setAttrByPath
    ;
  inherit (lib.lists) last singleton;
  inherit (lib.modules) mkIf;
  inherit (lib.options) literalExpression mkEnableOption mkOption;
  inherit (lib.trivial) pipe;
  locPath = [
    "hardware"
    "memory"
  ];
  loc = concatStringsSep "." locPath;
  mem = getAttrFromPath locPath config;
  memOpt = getAttrFromPath locPath options;

  # module implementation

  levelChoicesList = [
    # order MUST be equal to the numeric order above
    "minimum"
    "average"
    "maximum"
  ];

  orderAssertion = prefix: cfg: lowerName: higherName: {
    assertion = cfg.${lowerName} <= cfg.${higherName};
    message = "${prefix}: expected ${lowerName} <= ${higherName}; actual ${toString cfg.${lowerName}} > ${toString cfg.${higherName}}";
  };
  sumAssertion =
    level:
    let
      sum = pipe mem.assignments [
        (mapAttrsToList (name: val: val."${level}Bytes"))
        (foldl' (a: e: a + e) 0)
      ];
    in
    {
      assertion = sum <= mem.maximumBytes;
      message = "${loc}: more ${level} memory assigned (${toString sum} bytes) than the maximum (${toString mem.maximumBytes} bytes), repl ${loc}.assignments for full overview";
    };
  assertionToWarning = { assertion, message }: mkIf (!assertion) message;

  assigmentModule =
    { name, config, ... }:
    {
      options = {
        name = mkOption {
          description = ''
            The name of the module making the assignment.

            This should contain the full module name (see example)
            to avoid name clashes
            and to make the definition source visible to the user.
            Modules are allowed to define multiple assigments
            when using different names for each assignment,
            e.g. `services.redis.servers.<name>` for multi-instance modules.

            The name read-only and interfered from the attribute name,
            as its only purposes are disambiguation
            and for display in user informations.
          '';
          type = types.str;
          readOnly = true;
          default = name;
          example = "services.postgres";
        };
        minimumBytes = mkOption {
          description = ''
            Minimum amount of system memory
            the declaring module or service requires to work at all,
            expressed in bytes.

            Services should be able to reasonably expect
            that this amount of memory is available exclusively to them.
            Services which are capable to reduce their memory usage
            in case of memory pressure (e.g. ZFS ARC)
            should set this to a amount lower than the other assignment values
            to reflect their ability.

            If the sum of all defined minimum requirements
            surpasses the overall maximum,
            an error is raised
            to prevent the configuration from being deployed.
          '';
          type = types.ints.positive;
          default = config.averageBytes;
          defaultText = ".averageBytes";
        };
        averageBytes = mkOption {
          description = ''
            Average amount of system memory
            the declaring module or service intends to use,
            expressed in bytes.

            The average a service defines
            should reflect the minimum amount of memory it requires
            to work *without intense performance degredation*.

            If the sum of all definitions average requirements
            surpasses the overall maximum,
            a warning or error, depending on deployer preference,
            will be raised.
          '';
          type = types.ints.positive;
        };
        maximumBytes = mkOption {
          description = ''
            Maximum amount of system memory
            the declaring module or service is able to use,
            expressed in bytes.

            The amount defined should reflect
            what services are able to reasonably use
            to improve their overall performance.
            In case there is no such theoritical upper limit,
            services can define their configured, default, or expected maximum
            (e.g. for ZFS ARC: 50 % of available memory).

            If the sum of all defined maximum requirements
            surpasses the overall maximum,
            a warning, if enabled, will be raised.
          '';
          type = types.ints.positive;
          default = config.averageBytes;
          defaultText = ".averageBytes";
        };
      };
    };

in
{

  options = setAttrByPath locPath {
    enableWarnings =
      mkEnableOption ''
        warnings \& errors for expected system memory use
        based on module configuration.

        This will be automatically enabled
        in case {option}`${loc}.availableBytes` is configured.
        This can be directly enabled
        to force {option}`${loc}.availableBytes` to be configured.
      ''
      // {
        default = memOpt.availableBytes.isDefined;
        defaultText = literalExpression "options.${loc}.availableBytes.isDefined";
      };
    assignments = mkOption {
      description = ''
        Allows modules to define their intended use of system memory.

        This is used to issue warnings or errors on system build
        in case multiple modules intend to configure their services
        to use a lot of system memory.

        Amounts in assignments can be adapted
        based on the value of {option}`${loc}.availableBytes`.
      '';
      type = with types; attrsOf (submodule assigmentModule);
      default = { };
    };
    availableBytes = mkOption {
      description = ''
        The amount of system memory
        which will be (at least) available to this system,
        expressed in bytes.

        If this is configured,
        {option}`${loc}.enableWarnings` will also be enabled by default.

        Other modules can use this value
        to dynamically adapt their services’ configurations
        in case they cannot do that adaption at runtime.
        If possible & reasonable,
        the default configuration of other modules
        should avoid to use this option,
        aside from being for values in {option}`${loc}.assignments`.

        Also, modules using this value for their own configuration
        must define their usage in {option}`${loc}.assignments`.
      '';
      type = types.ints.positive;
      # TODO explicit error message via default
      example = literalExpression "4 * 1024 * 1024 * 1024 # = 4 GiB";
    };
    maximumBytes = mkOption {
      description = ''
        The amount of system memory
        which will be the maximum available to this system,
        expressed in bytes.

        This must only be used to generate appropiate warnings.
        Other modules must read {option}`${loc}.availableBytes`
        to automatically configure the use of memory for other applications.
      '';
      type = types.ints.positive;
      default = mem.availableBytes;
      defaultText = literalExpression "config.${loc}.availableBytes";
      example = literalExpression "1024 * 1024 * 1024 * 1024 # = 1 TiB";
    };
    warnOn = mkOption {
      description = ''
        The warning level for memory usage.

        A warning is raised
        when the sum of these definitions in {option}`${loc}.assignments`
        surpasses {option}`${loc}.maximumBytes`.
      '';
      type = types.enum levelChoicesList;
      default = last levelChoicesList;
      example = "average";
    };
    errorOn = mkOption {
      description = ''
        The error level for memory usage.

        An error preventing the deployment of this configuration is raised
        when the sum of these definitions in {option}`${loc}.assignments`
        surpasses {option}`${loc}.maximumBytes`.
      '';
      type = types.enum levelChoicesList;
      default = head levelChoicesList;
      example = "average";
    };
  };

  config = mkIf mem.enableWarnings {

    assertions = concatLists [
      # global option checks
      [
        (orderAssertion loc mem "availableBytes" "maximumBytes")
      ]
      # per assignment option checks
      (pipe mem.assignments [
        (mapAttrsToList (name: cfg: orderAssertion "${loc}.assignments.\"${name}\"" cfg))
        (concatMap (gen: [
          (gen "minimumBytes" "averageBytes")
          (gen "averageBytes" "maximumBytes")
        ]))
      ])
      # actual memory check
      (singleton (sumAssertion mem.errorOn))
    ];

    warnings = singleton (assertionToWarning (sumAssertion mem.warnOn));

  };

}
