{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.x-banananetwork.improvedDefaults;
in
{

  _class = "nixos";

  config = lib.mkIf cfg.enable (
    let
      nixI = config.programs.nix-index;
      shellInt = builtins.any (x: x) (
        with nixI;
        [
          enableBashIntegration
          enableZshIntegration
        ]
      );
      nixIclash = nixI.enable && shellInt;
    in
    {

      programs.command-not-found.enable = lib.mkIf nixIclash false;

    }
  );

}
