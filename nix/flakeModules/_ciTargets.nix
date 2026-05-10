{
  lib,
  flake-parts-lib,
  self,
  ...
}:
let
  self_reference = ./_ciTargets.nix;
  module_name = "x-banananetwork_ci-targets";

  inherit (builtins) attrNames concatLists concatStringsSep;
  inherit (lib) types;
  inherit (lib.attrsets) showAttrPath;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) pipe;
  inherit (flake-parts-lib) mkTransposedPerSystemModule;

  mkListOption = mkOption {
    type = with types; listOf str;
    internal = true;
    visible = false;
  };
  mkTextOption = mkOption {
    type = types.str;
    internal = true;
    visible = false;
  };
in
{

  _class = "flake";

  imports = [
    (mkTransposedPerSystemModule {
      file = self_reference;
      name = module_name;
      option = mkOption {
        type = types.submodule {
          options = {
            # everything that should be provided by a remote cache for speeding up updates & so on
            # - caching older versions makes less sense
            # - and probably requires a lot of storage
            buildTargets = mkListOption;
            buildTargetsText = mkTextOption;
            # everything that should be at least built once per "release" to ensure working systems
            # - caching older versions makes sense (e.g. for bisecting)
            # - ideally, those require nearly no storage
            testTargets = mkListOption;
            testTargetsText = mkTextOption;
          };
        };
        internal = true;
        visible = false;
      };
    })
  ];

  config.perSystem =
    {
      config,
      self',
      system,
      ...
    }:
    let
      cfg = config.${module_name};

      buildIdListGen =
        { source, genPath }:
        attr:
        {
          suffix ? "",
        }:
        pipe source.${attr} [
          attrNames
          (map (elem: genPath attr elem + suffix))
        ];
      buildIdList = buildIdListGen {
        source = self;
        genPath =
          attr: elem:
          showAttrPath [
            attr
            elem
          ];
      };
      buildIdListSys = buildIdListGen {
        source = self';
        genPath =
          attr: elem:
          showAttrPath [
            attr
            system
            elem
          ];
      };

      concatLines = concatStringsSep "\n";
    in
    {
      ${module_name} = {

        buildTargets = concatLists [
          (buildIdListSys "devShells" { })
          (buildIdList "nixosConfigurations" { suffix = ".config.system.build.toplevel"; })
          # last one to be available as result on manual execution
          [ "nixosConfigurations.mgmt-iso.config.system.build.isoImage" ]
        ];

        testTargets = buildIdListSys "checks" { };

        # translate to text lists
        buildTargetsText = concatLines cfg.buildTargets;
        testTargetsText = concatLines cfg.testTargets;

      };
    };

}
