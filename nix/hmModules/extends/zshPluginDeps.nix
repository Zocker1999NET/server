{
  config,
  lib,
  pkgs,
  ...
}:
let
  zshCfg = config.programs.zsh;
  inherit (builtins) concatLists elem;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) optionals singleton;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.trivial) pipe;
  selectedPlugins = concatLists [
    (optionals zshCfg.antidote.enable zshCfg.antidote.plugins)
  ];
  # dependencies
  pluginDeps = {
    "djui/alias-tips" = singleton pkgs.python3;
  };
in
{
  _class = "homeManager";
  config = mkIf zshCfg.enable {
    home.packages = pipe pluginDeps [
      (mapAttrsToList (plugin: mkIf (elem plugin selectedPlugins)))
      mkMerge
    ];
  };
}
