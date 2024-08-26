{
  config,
  lib,
  osConfig ? null,
  ...
}:
let
  cfg = config.programs.zsh;
in
{
  config = lib.mkIf cfg.enable {

    assertions = lib.mkIf (!builtins.isNull osConfig) [
      # see https://github.com/nix-community/home-manager/blob/e1391fb22e18a36f57e6999c7a9f966dc80ac073/modules/programs/zsh.nix#L353
      {
        assertion = cfg.enableCompletion -> builtins.elem "/share/zsh" osConfig.environment.pathsToLink;
        message = ''
          for useful ZSH completion, add "/share/zsh" to NixOS environment.pathsToLink
        '';
      }
    ];

  };
}
