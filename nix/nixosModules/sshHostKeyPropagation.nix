{
  config,
  lib,
  pkgs,
  ...
}:
let

  # module constants
  moduleNamespace = "x-banananetwork";
  moduleName = "sshHostKeyPropagation";
  optPrefix = "${moduleNamespace}.${moduleName}";

  # helpers
  inherit (builtins)
    attrValues
    concatLists
    concatStringsSep
    filter
    ;
  inherit (lib) types;
  inherit (lib.attrsets) mapCartesianProduct;
  inherit (lib.lists) singleton unique;
  inherit (lib.modules) mkIf;
  inherit (lib.options) literalExpression mkEnableOption mkOption;
  inherit (lib.trivial) pipe;
  inherit (pkgs.writers) writeText;

  assertionToWarning = { assertion, message }: mkIf (!assertion) message;
  assertionsToWarnings = map assertionToWarning;

  # custom types
  configType = types.raw // {
    description = "NixOS configuration";
    check = a: a._type or null == "configuration";
  };
  flakeType = types.raw // {
    description = "Nix flake";
    check = a: a._type or null == "flake";
  };

  # host config
  cfg = config.${moduleNamespace}.${moduleName};

in
{

  _class = "nixos";

  options.${moduleNamespace}.${moduleName} = {

    # "sender"
    propagatedHostKeys = mkOption {
      description = ''
        Configures which host keys from this host should be propagated to other hosts of this flake.

        Can be set to {var}`[]` to excempt this host’s keys from propagation.

        This module does not have to enabled for this host’s keys to be propagated,
        read more at {option}`${optPrefix}.enable`.
      '';
      type = with types; listOf str;
      default = [ ];
    };
    propagatedHostNames = mkOption {
      description = ''
        The hostnames under which this host’s keys are propagated.

        Can be set to {var}`[]` to excempt this host’s keys from propagation.
        Duplicated entries are filtered before application.

        This module does not have to enabled for this host’s keys to be propagated,
        read more at {option}`${optPrefix}.enable`.
      '';
      type = with types; listOf str;
      default = with config.networking; [
        hostName
        fqdnOrHostName
      ];
      defaultText = literalExpression ''
        with config.networking; [
          hostName
          fqdnOrHostName
        ];
      '';
      apply = unique;
    };

    # "receiver"
    enable = mkEnableOption ''
      host key propagation for this host.

      This means that this host will have
      the host keys from all other hosts of the given sources
      in its known_hosts file for SSH.

      This mechanism may only get keys from hosts
      which have this module configured in their configs as well.
      But the module is only required to be enabled on the receiver side,
      hence you can disable it on hosts
      which should not receive the host keys from others
    ''; # <- full stop added by mkEnableOption
    sources = mkOption {
      description = ''
        The list of configurations where host keys are to be propagated from.

        Host keys are only propagated when this module is configured there as well.
        But this module is not required to be enabled on these hosts,
        it is only required to be enabled on this host.
        And this list may contain hosts where this module was not even imported,
        those hosts are silently ignored.

        Flake users may want to use the helper option
        {option}`${optPrefix}.sourceFlake`.
      '';
      type = with types; listOf configType;
      default = [ ];
    };
    sourceFlake = mkOption {
      description = ''
        The flake from which hosts’ keys are to be propagated from.

        The hosts are expected to be exported in the `nixosConfigurations` output of that flake.

        This option automatically supplies
        {option}`${optPrefix}.sources`.
      '';
      type = with types; nullOr flakeType;
      default = null;
      example = literalExpression "flake";
    };

  };

  config = mkIf cfg.enable {

    # implementation
    programs.ssh.knownHostsFiles = pipe cfg.sources [
      # where this module is loaded
      (map (host: (host.config.${moduleNamespace} or { }).${moduleName} or null))
      (filter (host: host != null))
      # build cartesian products of keys & names
      (map (
        hCfg:
        mapCartesianProduct ({ key, name }: "${name} ${key}") {
          key = hCfg.propagatedHostKeys;
          name = hCfg.propagatedHostNames;
        }
      ))
      concatLists
      (concatStringsSep "\n")
      (writeText "sshHostKeyPropagation.keys")
      singleton
    ];

    warnings = assertionsToWarnings [
      {
        assertion = cfg.sourceFlake != null -> cfg.sourceFlake.nixosConfigurations or null != null;
        message = "${optPrefix}.sourceFlake does not export any configurations with its nixosConfiguations output";
      }
    ];

    # simplifications
    ${moduleNamespace}.${moduleName} = {
      sources = mkIf (cfg.sourceFlake != null) (attrValues (cfg.sourceFlake.nixosConfigurations or { }));
    };

  };

}
