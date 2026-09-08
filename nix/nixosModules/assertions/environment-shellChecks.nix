# Strict shell checks for POSIX-compatible environment shell init options
# - runs shellcheck in POSIX mode (`-s sh`) on all `environment.*ShellInit` options
# - fails the build on any shellcheck error or warning
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) concatStringsSep;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
  cfg = config.environment;

  # all environment options which must be POSIX-compatible (pure sh)
  shellInitOptions = [
    "extraInit"
    "shellInit"
    "loginShellInit"
    "interactiveShellInit"
  ];

  # one shellcheck derivation per option, named by the option
  shellChecks = map (
    name:
    pkgs.runCommand "environment-${name}-shellcheck"
      {
        nativeBuildInputs = [ pkgs.shellcheck ];
        shellInit = cfg.${name};
        passAsFile = [ "shellInit" ];
      }
      ''
        # shellcheck in POSIX mode
        shellcheck -s sh "$shellInitPath" || {
          echo "environment.${name} is not POSIX-compatible (see shellcheck output above)" >&2
          exit 1
        }
        touch "$out"
      ''
  ) shellInitOptions;
in
{

  _class = "nixos";

  options.environment.enableStrictShellChecks = mkEnableOption ''
    checking all `environment` shell init options
    which must be POSIX-compatible (pure sh)
    with `shellcheck` in POSIX mode (`-s sh`).

    When enabled, the contents of
    ${concatStringsSep ", " (map (name: "{option}`environment.${name}`") shellInitOptions)}
    are checked with `shellcheck`,
    and any error or warning causes the build to fail.

    This option is disabled by default,
    and although some options have already been fixed,
    it is still likely that you will encounter build failures when enabling this.
    We encourage people to enable this option
    when they are willing and able to submit fixes for potential build failures.
  '';

  config = mkIf cfg.enableStrictShellChecks {

    system.checks = shellChecks;

  };

}
