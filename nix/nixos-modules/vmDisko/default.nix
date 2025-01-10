{
  config,
  lib,
  options,
  ...
}:
let
  self = options.x-banananetwork.vmDisko;
  cfg = config.x-banananetwork.vmDisko;
in
{

  # TODO upstream that to disko

  options.x-banananetwork.vmDisko = {

    enable = lib.mkEnableOption ''
      VM disk configuration with disko.
      Will be automatically enabled when option{x-banananetwork.vmDisko.generation} is manually set.
    '';

    mainDiskName = lib.mkOption {
      description = ''
        Name of the main disk.

        Similar to {option}`system.stateVersion`,
        **do not change this** unless you know what you are doing.
      '';
      type = lib.types.str;
    };

    generation = lib.mkOption {
      description = ''
        Disk generation to use.

        Similar to {option}`system.stateVersion`,
        **do not change this** unless you know what you are doing.

        See option {option}`x-banananetwork.vmDisko.generations`
        for a list of all generations available.
      '';
      type = with lib.types; nullOr str;
      default = null;
      example = self.recommendedGeneration.default;
    };

    recommendedGeneration = lib.mkOption {
      description = ''
        Disk generation recommended to use for new systems.
      '';
      default = "ext4-1";
      readOnly = true;
    };

    generationsDir = lib.mkOption {
      description = ''
        Directories where to search for generations.

        A generation must at least use one disk with the attr name `main`
        (through its label name can be different)
        because VMs are expected to have at least one disk as their primary available.
      '';
      type = lib.types.path;
      default = ./.;
      example = ./.;
    };

    generationPath = lib.mkOption {
      description = "Path to selected generation template.";
      readOnly = true;
      type = lib.types.path;
      default =
        assert lib.assertMsg (
          cfg.generation != null
        ) ".generation needs to be set for .generationPath to be available";
        let
          path = cfg.generationsDir + "/${cfg.generation}";
        in
        if builtins.pathExists path then path else path + ".nix";
      defaultText = lib.literalExpression ''
        with config.x-banananetwork.vmDisko;
        generationsDir + ("/''${generation}" or "/''${generation}.nix")
      '';
    };

  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.generation != null) { x-banananetwork.vmDisko.enable = true; })
    (lib.mkIf cfg.enable {

      assertions = [
        {
          assertion = cfg.enable -> cfg.generation != null;
          message = "x-banananetwork.vmDisko.generation must be set. Currently \"${cfg.recommendedGeneration}\" is recommended.";
        }
        {
          assertion = cfg.generation != null -> builtins.pathExists cfg.generationPath;
          message = "generation \"${cfg.generation}\" was not found in ${cfg.generationPath}";
        }
      ];

      disko.devices = lib.mkMerge [
        (import cfg.generationPath)
        {
          # avoid mixing VM disks
          # hint: mkOverride required because
          # - cfg.generations from above is already type-checked, hence priorities are discharged
          # - assigment from above has default priority of 100
          #disk.main.name = lib.mkOverride 99 cfg.mainDiskName;
          disk.main.name = cfg.mainDiskName;
        }
      ];

    })
  ];

}
