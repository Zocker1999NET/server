{
  config,
  lib,
  pkgs,
  ...
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

      enable = lib.mkDefault true;
      dev.enable = lib.mkDefault true;
      doc.enable = lib.mkDefault true;
      info.enable = lib.mkDefault true;

      man = {

        enable = lib.mkDefault true;
        generateCaches = true;

        man-db.enable = lib.mkDefault false; # see mandoc

        mandoc = {
          enable = lib.mkDefault true;
        };

      };

      nixos = {
        enable = lib.mkDefault true;
        includeAllModules = lib.mkDefault false; # otherwise rebuilds full manual on each change of value
      };

    };

    environment.systemPackages =
      with pkgs;
      let
        inherit (lib.lists) flatten optionals;
      in
      flatten [

        (optionals config.hardware.bluetooth.enable [
          bluetuith
        ])

        (optionals config.hardware.graphics.amd.enable [ nvtopPackages.amd ])
        (optionals config.hardware.graphics.intel.enable [
          intel-gpu-tools
          nvtopPackages.intel
        ])

        bat
        batmon # TODO only on systems wich batteries
        bmon # better than nethogs for graphs
        file
        manix
        massren
        nethogs # better than bmon for process identification
        reptyr
        psitop
        unixtools.xxd
        unzip
        up # ultimate plumber
        usbtop
        zip
      ];

    programs = {

      bandwhich.enable = true;

      git = {
        enable = true;
        config = {
          advice = {
            detachedHead = true;
          };
          alias = {
            lg1 = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all";
            lg2 = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(bold yellow)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)' --all";
            lg = ''!git lg1'';
          };
          core = {
            autocrlf = "input";
          };
          init = {
            defaultBranch = "main";
          };
          pull = {
            ff = "only";
          };
          push = {
            autoSetupRemote = true;
          };
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
