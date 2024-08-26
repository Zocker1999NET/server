{
  config,
  lib,
  osConfig ? null,
  ...
}:
let
  cfg = config.services.gpg-agent;
  hwSmartcards = osConfig.hardware.gpgSmartcards.enable;
  scDaemon = cfg.enable && cfg.enableScDaemon;
in
{
  config = lib.mkIf (!builtins.isNull osConfig) {

    assertions = [
      {
        assertion = scDaemon -> hwSmartcards;
        message = ''
          gpg-agent’s scDaemon is enabled but NixOS hardware.gpgSmartcards is disabled
        '';
      }
    ];

    warnings = [
      (lib.mkIf (hwSmartcards && !scDaemon) ''
        NixOS hardware.gpgSmartcards is enabled but gpg-agent’s scDaemon is disabled
      '')
    ];

  };
}
