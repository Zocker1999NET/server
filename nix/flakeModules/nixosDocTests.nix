{
  lib,
  flake-parts-lib,
  self,
  ...
}:
let
  self_reference = ./nixosDocTests.nix;

  inherit (builtins) attrValues listToAttrs mapAttrs;
  inherit (lib) types;
  inherit (lib.attrsets) nameValuePair;
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkForce mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) flip pipe;
  inherit (flake-parts-lib) mkPerSystemOption;

  mapAttrsPipe = tasks: mapAttrs (_: flip pipe tasks);

  optionsModule =
    { config, name, ... }:
    {
      options = {
        name = mkOption {
          description = "Name of the test case.";
          type = types.str;
          default = name;
        };
        buildDocsInSandbox = mkOption {
          description = ''
            Whether to build the module's documentation inside the docs "module" sandbox.

            When enabled, the modules are added to the docs via
            {option}`documentation.nixos.extraModules`.

            When disabled, the modules are added to the docs
            by being imported normally
            with {option}`documentation.nixos.includeAllModules` enabled.
          '';
          type = types.bool;
          default = true;
          example = false;
        };
        checkName = mkOption {
          description = "Full name used for the generated output attr name in checks.";
          type = types.str;
          default = "nixosDocTests:${name}";
        };
        derivationName = mkOption {
          description = "Full name used for the generated derivation in checks.";
          type = types.str;
          default = "nixos-manual_${name}";
        };
        module = mkOption {
          description = ''
            NixOS module to be tested.

            Syntactic sugar for `modules` option.
          '';
          type = with types; nullOr deferredModule;
          default = null;
        };
        modules = mkOption {
          description = "NixOS module to be tested.";
          type = with types; listOf deferredModule;
        };
      };
      config = {
        modules = mkIf (config.module != null) (singleton config.module);
      };
    };
in
{

  _class = "flake";

  options.perSystem = mkPerSystemOption {
    _file = self_reference;
    options.nixosDocTests = mkOption {
      description = ''
        Allows simple definitions of checks
        which tests whether the documentation parts of given nixosModules can be built.

        This is tested by building the full NixOS manual with all its default modules
        and the given modules appended.
      '';
      type = with types; lazyAttrsOf (submodule optionsModule);
      default = { };
    };
  };

  config.perSystem =
    { config, pkgs, ... }:
    {
      checks = pipe config.nixosDocTests [
        attrValues
        (map (
          cfg:
          nameValuePair cfg.checkName {
            _file = self_reference;
            imports = singleton (self.modules.nixosTest._default or { });
            config = {
              name = cfg.derivationName;
              nodes.tested.imports = [
                {
                  documentation = mkForce {
                    enable = true;
                    nixos.enable = true;
                  };
                }
                (
                  if cfg.buildDocsInSandbox then
                    {
                      documentation.nixos.extraModules = cfg.modules;
                    }
                  else
                    {
                      imports = cfg.modules;
                      documentation.nixos.includeAllModules = true;
                    }
                )
              ];
            };
          }
        ))
        listToAttrs
        (mapAttrsPipe [
          pkgs.testers.runNixOSTest
          (
            t:
            t.config.nodes.tested.system.build.manual.manual.overrideAttrs (_: _: { inherit (t.config) name; })
          )
        ])
      ];
    };

}
