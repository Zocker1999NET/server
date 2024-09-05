{
  config,
  lib,
  ...
}:
let
  cfg = config.services.openssh;
in
{

  options.services.openssh = {

    authorizedKeysOnly = lib.mkEnableOption ''
      only logins using ssh keys (improving over default settings)
    '';

  };

  config = lib.mkIf cfg.enable {

    services.openssh = {
      settings = {
        KbdInteractiveAuthentication = lib.mkIf cfg.authorizedKeysOnly false;
        PasswordAuthentication = lib.mkIf cfg.authorizedKeysOnly false;
      };
    };

  };

  # TODO add tests

}
