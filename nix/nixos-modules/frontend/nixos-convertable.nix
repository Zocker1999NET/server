{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.x-banananetwork.frontend;
  inherit (lib.modules) mkIf;
  inherit (lib.lists) optional;
in
{

  _class = "nixos";

  options.x-banananetwork.frontend = {
    convertable = lib.mkEnableOption "convertable specific settings";
  };

  config = mkIf cfg.enable {

    # on-screen keyboard (should just work, see https://discuss.kde.org/t/how-to-enable-virtual-keyboard-included-in-kde/264/2)
    users.users.${cfg.username}.packages = optional cfg.convertable pkgs.maliit-keyboard;

  };

}
