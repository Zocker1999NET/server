{ config, lib, ... }:
let
  cpu = config.hardware.cpu;
  anyArg = builtins.any (x: x) [
    # list of conditions which require cpu type to be known
    cpu.updateMicrocode
  ];
  cpuOpts =
    type:
    lib.mkIf (anyArg && cpu.type == type) {
      # options for all cpu types
      updateMicrocode = lib.mkDefault cpu.updateMicrocode;
    };
in
{

  _class = "nixos";

  options = {

    hardware.cpu = {

      type = lib.mkOption {
        description = ''
          Configures the CPU type to expect this configuration to run on.

          This setting is required when using generalizing options
          like option{hardware.cpu.updateMicrocode}.
        '';
        type =
          with lib.types;
          nullOr (enum [
            "amd"
            "intel"
          ]);
        # required
      };

      updateMicrocode = lib.mkEnableOption ''
        microcode updates for CPU type selected in option{hardware.cpu.type}
      '';

    };

  };

  config = {

    hardware.cpu = {
      amd = cpuOpts "amd";
      intel = cpuOpts "intel";
    };

  };

}
