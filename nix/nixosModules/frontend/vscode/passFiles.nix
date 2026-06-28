# WARNING: module is untested!
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  inherit (builtins) attrValues mapAttrs;
  inherit (lib) types;
  inherit (lib.attrsets) mapAttrs' nameValuePair;
  inherit (lib.modules) mkMerge;
  inherit (lib.options) mkOption;
  inherit (lib.strings) optionalString;
  inherit (lib.trivial) flip pipe;

  # copied from: https://github.com/nix-community/home-manager/blob/8d8a6cc50ddc60748791a14ee1163c865ec57635/modules/programs/vscode/default.nix#L21
  packageName = "vscode";
  nameShort = "Code";

  # copied from: https://github.com/nix-community/home-manager/blob/8d8a6cc50ddc60748791a14ee1163c865ec57635/modules/programs/vscode/mkVscodeModule.nix#L34
  userDir =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "${config.home.homeDirectory}/Library/Application Support/${nameShort}/User"
    else
      "${config.xdg.configHome}/${nameShort}/User";
  # (modified to be better extensible)
  profileDirPath =
    name: "${userDir}/${optionalString (name != "default") "profiles/${name}/"}settings.json";

  profileSubmodule = types.submodule {
    # _class = "homeManager.vscodeProfile";
    options.passFiles = mkOption {
      description = "Files to pass into the profile's home.file.";
      type = options.home.file.type;
      default = { };
      internal = true;
    };
  };
in
{

  _class = "homeManager";

  # merging module into the vscode profile submodule
  options.programs.${packageName}.profiles = mkOption {
    type = types.attrsOf profileSubmodule;
  };

  # passing over
  config.home.file = pipe config.programs.${packageName}.profiles [
    (mapAttrs (
      profileName:
      let
        profilePath = profileDirPath profileName;
      in
      profileCfg:
      flip mapAttrs' profileCfg.passFiles (
        fileName: fileCfg:
        nameValuePair "${profilePath}/${fileName}" (
          fileCfg
          // {
            target = "${profilePath}/${fileCfg.target}";
          }
        )
      )
    ))
    attrValues
    mkMerge
  ];

}
