{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.options) mkOption literalExpression;

  # Custom type that validates an attribute set is a flake by checking its `_type` attribute
  # Uses `or` to handle missing _type attribute gracefully
  flakeType = types.addCheck types.attrs (a: a._type or "" == "flake");

  system = pkgs.stdenv.hostPlatform.system;
  cachedFlakes = config.x-banananetwork.cachedFlakesDevShell;
in
{
  options.x-banananetwork = {
    cachedFlakesDevShell = mkOption {
      description = ''
        List of flakes whose default devShell for the current architecture will be cached.

        These shells will be included in the system closure to ensure
        they are available in the Nix store without needing to rebuild.
      '';
      type = with types; listOf flakeType;
      default = [ ];
      example = literalExpression ''
        [
          self
          inputs.nixpkgs
        ]
      '';
    };
  };

  config = {
    system.extraDependencies = map (flake: flake.devShells.${system}.default) cachedFlakes;
  };
}
