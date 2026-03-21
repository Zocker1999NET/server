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

            LONG_FLAG=""

            # Parse arguments
            while [[ $# -gt 0 ]]; do
              case "$1" in
                --long)
                  LONG_FLAG="1"
                  shift
                  ;;
                *)
                  echo "Usage: cheatsheet [--long]"
                  echo "  --long    Show the long version with detailed descriptions"
                  exit 1
                  ;;
              esac
            done

            if [[ -n "$LONG_FLAG" ]]; then
              ${lib.getExe pkgs.glow} "${cheatsheetLong}"
            else
              ${lib.getExe pkgs.glow} "${cheatsheetShort}"
            fi
          '';
        };
      in
      [
        cheatsheet
      ];
  };
}
