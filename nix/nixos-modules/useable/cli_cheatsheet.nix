{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.x-banananetwork.useable;
  cheatsheetShort = pkgs.writeTextFile {
    name = "cli_cheatsheet.md";
    text = builtins.readFile ./cli_cheatsheet.md;
  };
  cheatsheetLong = pkgs.writeTextFile {
    name = "cli_cheatsheet_long.md";
    text = builtins.readFile ./cli_cheatsheet_long.md;
  };
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      let
        cheatsheet = pkgs.writeShellApplication {
          name = "cheatsheet";
          runtimeInputs = with pkgs; [
            glow
          ];
          text = ''
            # Cheatsheet helper - displays available CLI tools

            print_help() {
              echo "Usage: cheatsheet [OPTIONS]"
              echo ""
              echo "Options:"
              echo "  -h, --help        Show this help message"
              echo "  -l, --long        Show the long version with detailed descriptions"
              echo "  --no-color        Disable colored output and formatting"
              echo "  -p, --pager       Enable pager to preserve colors when piping to less"
            }

            LONG_FLAG=""
            HELP_FLAG=""
            NO_COLOR_FLAG=""
            PAGER_FLAG=""

            # Parse arguments
            while [[ $# -gt 0 ]]; do
              case "$1" in
                -h|--help)
                  HELP_FLAG="1"
                  shift
                  ;;
                -l|--long)
                  LONG_FLAG="1"
                  shift
                  ;;
                --no-color)
                  NO_COLOR_FLAG="1"
                  shift
                  ;;
                -p|--pager)
                  PAGER_FLAG="1"
                  shift
                  ;;
                *)
                  print_help
                  exit 1
                  ;;
              esac
            done

            # Show help and exit if --help was specified
            if [[ -n "$HELP_FLAG" ]]; then
              print_help
              exit 0
            fi

            # Build glow arguments
            GLOW_ARGS=(--width 0)

            # Add pager only if requested
            if [[ -n "$PAGER_FLAG" ]]; then
              GLOW_ARGS+=(--pager)
            fi

            if [[ -n "$NO_COLOR_FLAG" ]]; then
              # Use plain style to disable colors but keep formatting
              GLOW_ARGS+=(--style "plain")
            else
              # Use auto style for colorful rendering
              GLOW_ARGS+=(--style "auto")
            fi

            # Add the cheatsheet file to args
            if [[ -n "$LONG_FLAG" ]]; then
              GLOW_ARGS+=("${cheatsheetLong}")
            else
              GLOW_ARGS+=("${cheatsheetShort}")
            fi

            ${lib.getExe pkgs.glow} "''${GLOW_ARGS[@]}"
          '';
        };
      in
      [
        cheatsheet
      ];
  };
}
