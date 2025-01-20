{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  # library
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkDefault mkIf mkMerge;
  inherit (lib.options) mkEnableOption;
  inherit (lib.trivial) max;
  # config
  cfg = config.x-banananetwork.zfsServer;
  servOpts = options.services.zfs;
  zfsPkg = config.boot.zfs.package;

  # custom ZFS pool management scripts
  mgmtScripts = [
    (pkgs.writeShellApplication {
      name = "zpool-create-enc";
      runtimeInputs = singleton zfsPkg;
      text = ''
        keydir="/root/zfs-keys";
        if [[ $# -lt 2 ]]; then
          echo "Usage: $0 <pool-name> <opts|layout>" >&2
          exit 1
        fi
        pool="$1"
        shift 1
        keyfile="$keydir/$pool"
        if [[ ! -r "$keyfile" ]]; then
          echo "Expected keyfile $keyfile to be prepared (readable file)" >&2
          exit 2
        fi
        set -x
        zpool create -O encryption=on -O keylocation="file://$keyfile" -O keyformat=hex "$pool" "$@"
      '';
    })
  ];

  # memory optimization
  memoryAssignmentName = "x-banananetwork.zfsServer";
  memoryAssigned = config.hardware.memory.assignments.${memoryAssignmentName};
  systemMemoryBytes = config.hardware.memory.availableBytes;

in
{

  options.x-banananetwork.zfsServer = {
    enable = mkEnableOption "banananet.work ZFS server config (including scrub & trim requiring timing)";
    warnOnDefaultTimings = mkEnableOption "warnings for default timings for ZFS scrub & trim" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    boot.supportedFilesystems.zfs = true;
    environment.systemPackages =
      mgmtScripts
      ++ (with pkgs; [
        jdupes
        zfs-tools
      ]);
    hardware.memory.assignments.${memoryAssignmentName} = mkMerge [
      # wild guess
      {
        averageBytes = mkDefault ((with memoryAssigned; maximumBytes + minimumBytes) / 2);
      }
      # from OpenZFS default module parameters
      {
        minimumBytes = mkDefault (max (32 * 1024 * 1024) (systemMemoryBytes / 32)); # zfs_arc_min
        maximumBytes = mkDefault (max (64 * 1024 * 1024) (systemMemoryBytes / 2)); # zfs_arc_max
      }
    ];
    services.zfs = {
      autoScrub.enable = true;
      trim.enable = true;
      # TODO zed.settings to send via ntfy script
    };
    warnings = mkIf cfg.warnOnDefaultTimings [
      (mkIf (
        servOpts.autoScrub.interval.highestPrio >= 1500
      ) "[zfsServer] services.zfs.autoScrub.interval still uses default value")
      (mkIf (
        servOpts.trim.interval.highestPrio >= 1500
      ) "[zfsServer] services.zfs.trim.interval still uses default value")
    ];
  };

}
