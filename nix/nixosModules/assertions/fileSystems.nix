{ config, ... }:
let
  inherit (builtins) any attrValues elem;
  allMounts = attrValues config.fileSystems;
  testDiskOption = option: disk: elem option disk.options;
  testDiskDiscard = testDiskOption "discard";
in
{
  _class = "nixos";
  config = {

    assertions = [
      {
        assertion = config.services.fstrim.enable -> !any testDiskDiscard allMounts;
        message = ''
          enabling "discard" mount option is discouraged because services.fstrim is enabled
        '';
      }
    ];

  };
}
