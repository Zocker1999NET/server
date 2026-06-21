{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) flatten optional optionals;

  # supported (ordered by long option name)
  steam = config.programs.steam;

in
{

  _class = "nixos";

  config.x-banananetwork.autoUnfree = {
    packages = flatten [
      # programs
      (optional steam.enable steam.package)
      # TODO improve pulling in dependencies more accurate
      (optionals steam.enable ([
        pkgs.steam-run
        pkgs.steam-unwrapped
      ]))
    ];
  };

}
