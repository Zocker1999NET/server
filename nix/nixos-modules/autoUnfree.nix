{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.x-banananetwork.autoUnfree;
in
{


  options = {

    x-banananetwork.autoUnfree = {

      enable = lib.mkEnableOption ''
        automatically allowing unfree packages
        based on other NixOS module’s options.

        This should make it easier to allow unfree packages,
        being kind of a replacement of generelly enabling
        option{nixpkgs.config.allowUnfree}.
        Through this module aims to be more restrictive
        as it only enables packages used by modules
        which are enabled in the host’s configuration.

        Be aware that this module may not support all modules installed in nixpkgs.
        And be aware that this module blocks the option
        option{nixpkgs.config.allowUnfreePredicate} for other uses.

        Other modules can add support on their own
        by using the option{x-banananetwork.autoUnfree.packages} option.
      '';

      packages = lib.mkOption {
        description = ''
          Lists all packages which should be allowed to be installed
          despite of them being unfree.
          Only works when option{x-banananetwork.autoUnfree.enable} is set to true.

          This option is mainly intended to be used by other module developers
          to add support for this on their own.

          Users may also use this additionally allow packages on their own.
        '';
        type = lib.types.listOf lib.types.package;
        default = [ ];
        example = lib.literalText ''
          with pkgs; [
            vscode
          ] ++ with lib.lists; flatten [
            # just as an example, this is already supported internally
            (optional config.programs.steam.enable config.programs.steam.package)
          ]
        '';
      };

    };

  };


  config = lib.mkIf cfg.enable {


    nixpkgs.config = {

      allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) (map lib.getName cfg.packages);

    };


    # TODO add alternative for allowUnfreePredicate for users


    x-banananetwork.autoUnfree.packages =
      let
        inherit (lib.lists) flatten optional;
        # supported (ordered by long option name)
        amd = config.hardware.cpu.amd;
        intel = config.hardware.cpu.intel;
        steam = config.programs.steam;
      in
      flatten [
        # hardware.cpu
        # TODO in nixpkgs, create {amd,intel}.microcodePackage options
        # TODO test if this is really required
        #(optional amd.updateMicrocode pkgs.microcodeAmd)
        #(optional intel.updateMicrocode pkgs.microcodeIntel)
        # programs
        (optional
          steam.enable
          steam.package)
      ];


  };


}
