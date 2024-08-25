{ lib, outputs, ... }@flakeArg:
{ pkgs, system, ... }@sysArg:
{

  secrix-wrapper =
    let
      secrixExe = outputs.apps.${system}.secrix.program;
    in
    pkgs.writeShellApplication {
      name = "secr";
      text = ''
        secrix() {
          set -x
          exec ${secrixExe} "$@"
        }

        help() {
          echo "Usages:"
          echo "  $0 [create|rekey|edit|encrypt] <system> [<args> …] <file>"
          echo "  $0 decrypt [<args> …] <file>"
        }

        main() {
          if [[ $# -lt 1 ]]; then
            help
            exit 0
          fi
          cmd="$1"
          shift 1
          case "$cmd" in
            help|-h|--help)
              help
              ;;
            create)
              secrix "$cmd" --all-users --system "$@"
              ;;
            rekey|edit)
              secrix "$cmd" --identity "$SECRIX_ID" --all-users --system "$@"
              ;;
            encrypt)
              secrix "$cmd" --all-users --system "$@"
              ;;
            decrypt)
              secrix "$cmd" --identity "$SECRIX_ID" "$@"
              ;;
          esac
        }

        main "$@"
      '';
    };

}
