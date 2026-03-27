{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) concatStringsSep;
  inherit (lib.modules) mkIf;
  inherit (lib.options) literalExpression mkEnableOption mkOption;
  inherit (lib.trivial) pipe;

  cfg = config.services.hunspell;
in
{
  options.services.hunspell = {
    enable = mkEnableOption "hunspell dictionaries available to all applications";

    dictionaries = mkOption {
      description = ''
        List of hunspell dictionary packages to use.

        These packages are typically from `pkgs.hunspellDicts`.
        Each dictionary will be added to the DICPATH environment variable.

        Each package should provide its dictionaries under `''${pkg}/share/hunspell`.
      '';
      type = with lib.types; listOf package;
      default = [ ];
      example = literalExpression ''
        with pkgs.hunspellDicts; [
          de_DE
          en_US
        ]
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.variables = {
      # DICPATH is a colon-separated list of directories containing hunspell dictionaries
      DICPATH = pipe cfg.dictionaries [
        (map (dict: "${dict}/share/hunspell"))
        (paths: [ "${pkgs.hunspell}/lib/hunspell" ] ++ paths)
        (concatStringsSep ":")
      ];
    };
  };
}
