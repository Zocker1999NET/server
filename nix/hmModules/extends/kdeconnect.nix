{
  config,
  lib,
  osConfig ? null,
  pkgs,
  ...
}:
let
  cfg = config.services.kdeconnect;
  configDescPreamble = ''
    Configuring KDE Connect using these options is probably not endorsed by upstream
    as no user documentation for these configuration files exist.
  '';
  optionDescPreamble = ''
    ${configDescPreamble}
    {option}`services.kdeconnect.enableSettings` must be enabled
    for this option to be applied.
  '';
  typeConfig = pkgs.formats.ini { };
in
{

  options.services.kdeconnect = {

    enableSettings = lib.mkEnableOption ''
      KDE Connect settings defined in this module.

      ${configDescPreamble}

      This option operates independently of {option}`services.kdeconnect.enable`
      and so can also be used when KDE Connect is already installed by other means,
      e.g. using the NixOS module option `programs.kdeconnect.enable`
    '';

    settings = {
      name = lib.mkOption {
        description = ''
          Name of this device, advertised to other KDE Connect devices

          ${optionDescPreamble}
        '';
        type = lib.types.str;
        default = osConfig.networking.hostName;
        defaultText = lib.literalExpression "osConfig.networking.hostName";
      };
      customDevices = lib.mkOption {
        description = ''
          List of IPs & hostnames KDE Connect should try to connect to.
          Useful in scenarios where auto discover does not work,
          e.g. when combined with VPN.

          ${optionDescPreamble}
        '';
        # TODO limit to IPs
        # TODO check if hostname works now
        type = with lib.types; listOf str;
        default = [ ];
        example = [
          "192.168.12.10"
          "192.168.12.11"
        ];
      };
    };

    config = lib.mkOption {
      description = ''
        Arbitary settings for KDE Connect.

        ${optionDescPreamble}
        This will then overwrite the file {file}`$XDG_CONFIG_DIR/kdeconnect/config`.
      '';
      type = typeConfig.type;
      default = { };
    };

  };

  config = {

    warnings = [
      (lib.mkIf cfg.enableSettings "programs.kdeconnect.enableSettings is experimental, be aware")
    ];

    services.kdeconnect.config =
      let
        sets = cfg.settings;
        optConcat = sep: list: lib.mkIf (list != [ ]) (lib.concatStringsSep sep list);
      in
      {
        General = {
          customDevices = optConcat "," sets.customDevices;
          name = sets.name;
        };
      };

    xdg.configFile."kdeconnect/config" = lib.mkIf cfg.enableSettings {
      # TODO make compatible with more systems
      onChange = ''
        ${pkgs.systemd}/bin/systemctl --user reload-or-restart app-org.kde.kdeconnect.daemon@autostart.service
      '';
      source = typeConfig.generate "kdeconnect-config" cfg.config;
    };

  };

}
