{
  inputs,
  lib,
  outputs,
  ...
}@flakeArg:
{ pkgs, system, ... }@sysArg:
let
  inherit (pkgs) callPackage;
  craneLib = inputs.crane.mkLib pkgs;
in
{

  librespot-auth = callPackage ./librespot-auth { inherit craneLib; };

  nft-update-addresses = callPackage ./nft-update-addresses { };

  pdfpagecount = pkgs.writeShellApplication {
    name = "pdfpagecount";
    runtimeInputs = with pkgs; [
      pdftk
      unixtools.column
    ];
    text = ''
      help() {
        echo "Usage:  $0 <pdf-file> ..."
      }

      if [[ $# -lt 1 ]]; then
        help >&2
        exit 2
      fi

      while [[ $# -ge 1 ]]; do
        page_num=$(pdftk "$1" dump_data | awk '/^NumberOfPages:/ {print $2}')
        echo "$page_num" "$1"
        shift 1
      done
    '';
  };

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

  zfs-tools = callPackage ./zfs-tools { };

}
