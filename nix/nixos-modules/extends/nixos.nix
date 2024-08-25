{ config, lib, ... }:
let
  channelsEn = config.nix.channel.enable;
  nixFeature = lib.trivial.flip builtins.elem config.nix.settings.experimental-features;
  packageNames = map lib.strings.getName config.environment.systemPackages;
  gitInst = builtins.elem "git" packageNames;
  gitEn = config.programs.git.enable;
in
{
  config = {

    assertions = [
      {
        assertion = !channelsEn -> nixFeature "flakes";
        message = ''
          You disabled Nix channels, then you should enable flakes, otherwise you cannot build a new config.
        '';
      }
      {
        assertion = (!channelsEn && nixFeature "flakes") -> (gitInst || gitEn);
        message = ''
          Missing git, which is required to interact with most flakes.
        '';
      }
      {
        assertion = nixFeature "flakes" -> nixFeature "nix-command";
        message = ''
          Nix experimental-feature "flakes" requires feature "nix-command"
        '';
      }
    ];

    warnings = [
      # TODO add link to this file
      (lib.mkIf (gitEn && !gitInst) ''
        (not relevant for you, please report to the module author) git package was not detected properly, fallback to programs.git module
      '')
    ];

  };
}
