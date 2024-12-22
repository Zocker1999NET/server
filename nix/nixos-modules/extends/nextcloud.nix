{ config, lib, ... }:
let
  imCfg = config.services.imaginary;
  ncCfg = config.services.nextcloud;
  inherit (lib) types;
  inherit (lib.modules) mkDefault mkIf;
  inherit (lib.options) mkOption;
in
{

  options.services.nextcloud = {
    configureImaginary = mkOption {
      description = ''
        Whether to configure the Imaginary service on this host
        and instruct Nextcloud to use it for image previews.

        This also sets {option}`services.nextcloud.settings.enabledPreviewProviders` to make use of Imaginary,
        thereby needing to relist all default providers,
        thereby possibly disabling future default providers.
      '';
      type = types.bool;
      default = false;
      example = true;
    };
  };

  config.services = mkIf (ncCfg.enable && ncCfg.configureImaginary) {
    imaginary = {
      enable = true;
      address = "localhost";
      port = 8088;
      settings = {
        return-size = true;
      };
    };

    nextcloud = {
      enableImagemagick = mkDefault false;
      settings = {
        preview_imaginary_url = "http://localhost:${toString imCfg.port}/";
        enabledPreviewProviders = [
          # Nextcloud default list
          ''OC\Preview\Krita''
          ''OC\Preview\MarkDown''
          ''OC\Preview\MP3''
          ''OC\Preview\OpenDocument''
          ''OC\Preview\TXT''
          # Imaginary
          # does bmp, x-bitmap, png, jpeg, gif, heic, heif, svg+xml, tiff, webp, illustrator
          ''OC\Preview\Imaginary''
          ''OC\Preview\ImaginaryPDF''
        ];
      };
    };
  };

}
