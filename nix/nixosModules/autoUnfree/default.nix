{
  config,
  lib,
  ...
}:
let
  cfg = config.x-banananetwork.autoUnfree;
  inherit (builtins) elem;
  inherit (lib) types;
  inherit (lib.modules) mkIf;
  inherit (lib.options) literalExpression mkEnableOption mkOption;
  inherit (lib.strings) getName;
in
{

  _class = "nixos";

  imports = [
    ./definitions.nix
  ];

  options = {

    x-banananetwork.autoUnfree = {

      enable = mkEnableOption ''
        automatically allowing unfree packages
        based on other NixOS module’s options.

        This should make it easier to allow unfree packages,
        being kind of a replacement of generelly enabling
        option{nixpkgs.config.allowUnfree}.
        Through this module aims to be more restrictive
        as it only enables packages used by modules
        which are enabled in the host’s configuration.

        Be aware that this module may not support all modules installed in nixpkgs.
        And be aware that this module blocks the option
        option{nixpkgs.config.allowUnfreePredicate} for other uses.

        Other modules can add support on their own
        by using the option{x-banananetwork.autoUnfree.packages} option.
      '';

      names = mkOption {
        description = ''
          Lists all package names which should be allowed to be installed
          despite of them being unfree.
          Only works when option{x-banananetwork.autoUnfree.enable} is set to true.

          This option is mainly intended to be used by other module developers
          to add support for this on their own.

          Users may also use this additionally allow packages on their own.
        '';
        type = with types; listOf str;
        default = [ ];
      };

      packages = mkOption {
        description = ''
          Lists all packages which should be allowed to be installed
          despite of them being unfree.
          Only works when option{x-banananetwork.autoUnfree.enable} is set to true.

          This option is mainly intended to be used by other module developers
          to add support for this on their own.

          Users may also use this additionally allow packages on their own.

          The package names are automatically extracted from the given packages
          and added to option{x-banananetwork.autoUnfree.names}.
        '';
        type = with types; listOf package;
        default = [ ];
        example = literalExpression ''
          with pkgs; [
            vscode
          ] ++ with lib.lists; flatten [
            # just as an example, this is already supported internally
            (optional config.programs.steam.enable config.programs.steam.package)
          ]
        '';
      };

    };

  };

  config = mkIf cfg.enable {

    nixpkgs.config.allowUnfreePredicate = pkg: elem (getName pkg) cfg.names;

    x-banananetwork.autoUnfree.names = map getName cfg.packages;

    # TODO add alternative for allowUnfreePredicate for users

  };

}
