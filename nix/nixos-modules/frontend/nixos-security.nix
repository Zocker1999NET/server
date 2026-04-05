{
  config,
  lib,
  ...
}:
let
  cfg = config.x-banananetwork.frontend;
  inherit (lib.modules) mkIf;
in
{
  _class = "nixos";
  config = mkIf cfg.enable {

    boot.loader.systemd-boot.editor = false;

  };
}
