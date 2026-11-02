{
  config,
  lib,
  pkgs,
  ...
}:
let
  cageCfg = config.services.cage;
  cfg = config.services.cage.audio;
  pipewirePkg = config.services.pipewire.package;

  inherit (lib) types;
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkBefore mkDefault mkIf;
  inherit (lib.options) mkEnableOption mkOption;

  debugReportFull = "~/cage-pipewire-dump.log";
  debugReportConcise = "~/cage-pipewire-properties.log";
in
{

  _class = "nixos";

  options.services.cage.audio = {

    enable = mkEnableOption "audio support for cage";

    debugReport = mkEnableOption "writing a report containing a list of all audio devices and their properties into ${debugReportFull} and ${debugReportConcise}";

    defaultSinkMatcher = mkOption {
      description = ''
        Matcher for the default audio sink to use for cage.

        For more information, see the
        [WirePlumber documentation](https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/modifying_configuration.html#working-with-rules).
      '';
      type = with types; attrsOf str;
      example."node.name" = "alsa_output.pci-0000_00_03.0.hdmi-stereo";
    };

    volume = mkOption {
      description = ''
        Volume to configure for the default audio sink.
        This is applied to all channels.

        Corresponds to the `device.routes.default-sink-volume` attribute in WirePlumber.

        **Note**: To keep options simpler, this is configured for all devices, not just the default sink's device.
      '';
      type = with types; numbers.between 0.0 1.0;
      default = 1.0;
    };

  };

  config = mkIf (cageCfg.enable && cfg.enable) {

    # pipewire uses rtkit to gain realtime priority for low-latency audio
    security.rtkit.enable = mkDefault true;

    services.cage.commands = mkIf cfg.debugReport (mkBefore ''
      # wait some time for all audio devices to be initialized
      sleep 3
      ${pipewirePkg}/bin/pw-dump > ${debugReportFull}
      ${getExe pkgs.jq} -r '
        .[] | select(.type == "PipeWire:Interface:Node")
        | select((.info.props["media.class"] // "") | IN("Audio/Sink", "Audio/Source", "Video/Source"))
        | "\n== id=" + (.id|tostring) + " media.class=" + .info.props["media.class"] + " ==",
          (.info.props | to_entries | sort_by(.key) | map("  \(.key) = \(.value|tostring)") | .[])
      ' < ${debugReportFull} > ${debugReportConcise}
    '');

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;

      wireplumber = {
        enable = true;
        extraConfig = {

          "10-stateless-audio" = {
            "wireplumber.profiles".main = {
              "hooks.device.profile.state" = "disabled";
              "hooks.device.routes.state" = "disabled";
              "hooks.default-nodes.state" = "disabled";
              "hooks.stream.state" = "disabled";
            };
            "wireplumber.settings" = {
              "device.restore-profile" = false;
              "device.restore-routes" = false;
              "node.restore-default-targets" = false;
              "node.stream.restore-props" = false;
              "node.stream.restore-target" = false;
              "bluetooth.use-persistent-storage" = false;
            };
          };

          "50-audio-config" = {
            "monitor.alsa.rules" = singleton {
              matches = singleton cfg.defaultSinkMatcher;
              actions.update-props."priority.session" = 10000;
            };
            # we either set this global here,
            # or a per-sink property which gets overridden by a device default property on first use
            # (see https://gitlab.freedesktop.org/pipewire/wireplumber/-/commit/eef9baee611672f5086b9bc3bf58a4380baf0739),
            # or a per-device property which requires module users to specify an additional device matcher
            # -> most setups should only have one audio device in use, so this is the simplest option
            "wireplumber.settings"."device.routes.default-sink-volume" = cfg.volume;
          };

        };
      };
    };

  };

}
