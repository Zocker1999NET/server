{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.x-banananetwork.useable;
in
{


  options = {

    x-banananetwork.useable = {

      enable = lib.mkEnableOption ''
        a set of opionated options to make systems useable & debugable for users.

        This means e.g. adding common, useful tools and add documentation.
      '';

    };

  };


  config = lib.mkIf cfg.enable {


    documentation = {
      enable = true;
      dev.enable = true;
      doc.enable = true;
      info.enable = true;
      man.enable = true;
      man.generateCaches = true;
      man-db.enable = false; # see mandoc
      mandoc = {
        enable = true;
      };
      nixos = {
        enable = true;
        includeAllModules = true;
      };
    };


    environment.systemPackages = with pkgs; let
      inherit (lib.lists) flatten optional optionals;
    in
    flatten [

      (optional (config.hardware.bolt.enable && config.services.desktopManager.plasma6.enable) kdePackages.plasma-thunderbolt) # TODO upstream

      (optionals config.hardware.graphics.amd.enable [
        nvtopPackages.amd
      ])
      (optionals config.hardware.graphics.intel.enable [
        intel-gpu-tools
        nvtopPackages.intel
      ])

      bat
      batmon # TODO only on systems wich batteries
      jq # JSON
      manix
      massren
      nethogs
      reptyr
      pciutils
      psitop
      pv
      unixtools.xxd
      up # ultimate plumber
      usbtop
      usbutils

    ];


    programs = {

      bandwhich.enable = true;

      git = {
        enable = true;
        # TODO config
        init = {
          defaultBranch = "git";
        };
      };

      iftop.enable = true;

      iotop.enable = true;

      less = {
        enable = true;
      };

      liboping.enable = true;

      mtr.enable = true;

      nano = {
        enable = true;
        nanorc = ''
          set nowrap
          set tabtospaces
          set tabsize 2
        '';
        syntaxHighlight = true;
      };

      tmux = {
        plugins = with pkgs.tmuxPlugins; [
          better-mouse-mode
          sensible
        ];
        secureSocket = true; # does not survive user logout
      };

      zsh = {
        autosuggestions = {
          enable = true;
          strategy = [
            "history"
            "completion"
          ];
        };
        enable = true;
        enableBashCompletion = true;
        enableCompletion = true;
        syntaxHighlighting = {
          enable = true;
          highlighters = [
            "main"
            "brackets"
            "root"
          ];
        };
        vteIntegration = true;
      };

    };


    x-banananetwork = {

      allCommon.enable = true;
      debugMinimal.enable = true;

    };


    # TODO withlist:
    # - update tmuxPlugins.sensible in nixpkgs (e.g. https://github.com/NixOS/nixpkgs/pull/272954)


  };


}
