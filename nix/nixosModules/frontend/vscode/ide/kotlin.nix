{
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins)
    abort
    hasAttr
    isList
    isString
    mapAttrs
    typeOf
    ;
  inherit (lib.trivial) flip;
  inherit (pkgs.nix-vscode-extensions.vscode-marketplace-release.jetbrains) kotlin-server;

  extendingAttrs =
    pkg: attrs:
    pkg.overrideAttrs (
      old:
      flip mapAttrs attrs (
        name: value:
        let
          oldValue = old.${name};
        in
        if !hasAttr name old then
          value
        else if isList value && isList oldValue then
          oldValue ++ value
        else if isString value && isString oldValue then
          oldValue + value
        else
          abort "extendingAttrs: do not support extending attribute ${name} of type ${typeOf oldValue} with value of type ${typeOf value}"
      )
    );

  patchedKotlinServer = extendingAttrs kotlin-server {
    # fixes "EROFS: read-only file system"
    # until https://github.com/Kotlin/kotlin-lsp/issues/226 is patched
    postPatch = ''
      substituteInPlace out/dist/extension.js \
        --replace-fail '&&(0,external_fs_.chmodSync)(e,493)' ""
    '';
    # make embedded kotlin-lsp binary executable on NixOS
    nativeBuildInputs = [
      pkgs.autoPatchelfHook
    ];
    buildInputs = with pkgs; [
      # cSpell:disable
      alsa-lib # libasound.so.2
      freetype # libfreetype.so.6
      libx11 # libX11.so.6
      libxkbcommon # libxkbcommon.so.0
      libxext # libXext.so.6
      libxi # libXi.so.6
      libxrender # libXrender.so.1
      libxtst # libXtst.so.6
      stdenv.cc.cc.lib
      wayland # libwayland-client.so.0
      zlib # libz.so.1
      # cSpell:enable
    ];
  };
in
{

  # _class = "homeManager.vscodeProfile";

  extensions = with pkgs.nix-vscode-extensions.vscode-marketplace-release; [
    # cSpell:disable
    vscjava.vscode-gradle # JDK not added to PATH by this extension, because that is project specific
    patchedKotlinServer
    # cSpell:enable
  ];

}
