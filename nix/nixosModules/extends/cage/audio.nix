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

    channelVolumes = mkOption {
      description = ''
        Channel volumes for the default audio sink.

        The channel volumes are a list of floats between 0.0 and 1.0,
        where each float represents the volume for a channel in the default sink.

        Corresponds to the `node.param.Props` attribute `channelVolumes` in WirePlumber.

        When the list length != number of channels,
        WirePlumber normalizes the list by averaging all values
        and filling all channels with that average value.
      '';
      type = with types; listOf (numbers.between 0.0 1.0);
      default = [ 1.0 ];
    };

    defaultSinkMatcher = mkOption {
      description = ''
        Matcher for the default audio sink to use for cage.

        For more information, see the
        [WirePlumber documentation](https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/modifying_configuration.html#working-with-rules).
      '';
      type = with types; attrsOf str;
      example."node.name" = "alsa_output.pci-0000_00_03.0.hdmi-stereo";
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

          "50-audio-config"."monitor.alsa.rules" = singleton {
            matches = singleton cfg.defaultSinkMatcher;
            actions.update-props = {
              "node.param.Props" = {
                inherit (cfg) channelVolumes;
                mute = false;
              };
              "priority.session" = 10000;
            };
          };

        };
      };
    };

  };

}
