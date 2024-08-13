{ nixosConfig
, config
, lib
, pkgs
, ...
}:

let
  myGpgKey = pkgs.fetchurl {
    url = "https://keys.openpgp.org/vks/v1/by-fingerprint/73D09948B2392D688A45DC8393E1BD26F6B02FB7";
    hash = "sha256-qVHrSLSRdcOL+pgDS1NAkmVScFdKxDA8FAm81UCYJ64=";
  };
  archiveGpgKey = pkgs.fetchurl {
    url = "https://keys.openpgp.org/vks/v1/by-fingerprint/19C17AF30A1152D473A3849C28279F3E0A444E63";
    hash = "sha256-k81wvlyx3oUJjKx1Dpmas1LLvTwKW8FN4MEbOvfRyj8=";
  };
in
{


  home = {

    stateVersion = nixosConfig.system.stateVersion;

  };


  home.file = {

    # TODO use generator for YAML
    # TODO sptlrx player detection broken because ".instanceXXXX" suffixes
    #   v1.2.2 fixes this, but its test requires network, making it hard to package for NixOS
    ".config/sptlrx/config.yaml".text = ''
      player: mpris
      timerInterval: 200
      updateInterval: 2000
      mpris:
        players:
          - ncspot
    '';

    ".ssh/connections/.keep".text = ''
      # created by home-manager (to create directory)
    '';

  };


  home.packages = with pkgs; [

    # dev
    neovim
    podman

    # media
    ncspot
    sptlrx # spotify subtitle generator
    # TODO server with: your_spotify

    # tools
    fzf # fuzzy finder  # TODO integrate better: https://home-manager-options.extranix.com/?query=fzf&release=master
    jdupes

    # UI
    element-desktop
    kdePackages.filelight
    kdePackages.kleopatra
    keepassxc
    krita
    wireshark
    trilium-desktop
    xournalpp
    yubikey-manager
    yubioath-flutter

    # utilities
    fira
    (pkgs.nerdfonts.override {
      fonts = [
        "FiraCode"
        "Hasklig"
      ];
    })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')

  ];


  programs = {

    bash = {
      enable = true;
      enableCompletion = true;
      # fix for https://github.com/nix-community/home-manager/issues/3091, from https://github.com/NixOS/nix/issues/2033#issuecomment-1366974053
      #bashrcExtra = ''
      #  export  NIXPATH="/nix/var/nix/profiles/per-user/$USER/channels:nixos-config=/etc/nixos/configuration.nix"
      #'';
    };

    chromium = {
      dictionaries = with pkgs.hunspellDictsChromium; [
        de_DE
        en_US
      ];
      enable = true;
      extensions = map (id: { id = id; }) [
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
        "oboonakemofpalcgghocfoadofidjkkk" # KeePassXC-Browser
      ];
      # TODO try ungoogled chromium
      #package = pkgs.ungoogled-chromium;
    };

    eza = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      git = true;
      icons = true;
    };

    git = {
      enable = true;
      userName = "Felix Stupp";
      userEmail = "felix.stupp@banananet.work";
      signing = {
        key = "73D09948B2392D688A45DC8393E1BD26F6B02FB7";
        signByDefault = true;
      };
    };

    gpg = {
      enable = true;
      mutableKeys = false;
      mutableTrust = false;
      publicKeys = [
        { source = "${myGpgKey}"; trust = 5; }
        { source = "${archiveGpgKey}"; trust = 5; }
      ];
      scdaemonSettings = {
        # required because of pcscd used in parallel
        disable-ccid = true;
      };
    };

    mpv = {
      enable = true;
      bindings = {
        MBTN_MID = "quit";
        WHEEL_UP = "ignore";
        WHEEL_DOWN = "ignore";
        WHEEL_LEFT = "ignore";
        WHEEL_RIGHT = "ignore";
      };
      extraInput = ''
        [ ignore
        ] ignore
        [ add speed -0.05
        ] add speed 0.05
        { ignore
        } ignore
        { add speed -0.2
        } add speed 0.2
      '';
      config = {
        save-position-on-quit = true;
        vo = "gpu"; # or: dmabuf-wayland
        hwdec = "auto-safe";
        gpu-context = "wayland";
        alpha = "yes";
        speed = 1.2;
        #ytdl-format = "bestvideo[height<=?1080]+bestaudio/best";
      };
      scripts = with pkgs.mpvScripts; [
        autoload
        evafast
        modernx-zydezu
        mpris
        quack
        quality-menu
        reload
        sponsorblock
        thumbfast
      ];
      scriptOpts = {
        modernx = {
          # order by README (https://github.com/zydezu/ModernX#configurable-options)

          # general
          welcomescreen = true;

          # interface
          persistentprogress = true;

          # button
          timetotal = false;
          downloadbutton = false;
          showyoutubecomments = false;

        };
      };
    };

    vscode = {
      enable = true;
      enableExtensionUpdateCheck = true;
      enableUpdateCheck = false;
      extensions = with pkgs.vscode-extensions; [
        # general
        dracula-theme.theme-dracula
        vscodevim.vim
        # IDE-specific
        jnoortheen.nix-ide
      ];
      mutableExtensionsDir = false;
      package = pkgs.vscodium;
      userSettings = {

        "[nix]" = {
          "editor.tabSize" = 2;
        };

        "[python]" = {
          "editor.defaultFormatter" = "ms-python.black-formatter";
        };

        "ansible.ansibleLint.path" = "${pkgs.ansible-lint}/bin/ansible-lint";

        "dev.containers.dockerComposePath" = "${pkgs.podman-compose}/bin/podman-compose";
        "dev.containers.dockerPath" = "${pkgs.podman}/bin/podman";

        "diffEditor.ignoreTrimWhitespace" = false;
        "diffEditor.renderSideBySide" = false;

        "editor.cursorBlinking" = "solid";
        "editor.fontFamily" = "'FiraCode Nerd Font', 'Fira Code','Droid Sans Mono', 'monospace', monospace, 'Droid Sans Fallback'";
        "editor.fontLigatures" = true;
        "editor.formatOnSave" = true;
        "editor.largeFileOptimizations" = false;
        "editor.minimap.enabled" = false;
        "editor.renderWhitespace" = "boundary";
        "editor.suggest.localityBonus" = true;
        "editor.suggestSelection" = "recentlyUsedByPrefix";
        "editor.wordWrap" = "on";

        "explorer.compactFolders" = true;
        "explorer.confirmDelete" = false;

        "extensions.ignoreRecommendations" = true;

        "files.associations" = {
          "*.makefile" = "makefile";
        };
        "files.autoSave" = "onFocusChange";
        "files.exclude" = {
          "**/.classpath" = true;
          "**/.factorypath" = true;
          "**/.mypy_cache" = true;
          "**/.project" = true;
          "**/.pytest_cache" = true;
          "**/.settings" = true;
          "**/__pycache__" = true;
          "**/venv" = true;
        };
        "files.insertFinalNewline" = true;
        "files.trimTrailingWhitespace" = true;
        "files.watcherExclude" = {
          "**/venv" = true;
        };

        "git.autofetch" = true;
        "git.confirmSync" = false;
        "git.enableSmartCommit" = true;

        "html.format.enable" = false;

        "keyboard.dispatch" = "keyCode";

        "latex-workshop.message.update.show" = false;
        "latex-workshop.view.pdf.viewer" = "tab";

        "markdown.preview.fontFamily" = "-apple-system, BlinkMacSystemFont, 'DejaVu Sans', 'Segoe WPC', 'Segoe UI', 'HelveticaNeue-Light', 'Ubuntu', 'Droid Sans', sans-serif";

        "mypy-type-checker.importStrategy" = "fromEnvironment";
        "mypy.runUsingActiveInterpreter" = true;

        "notebook.cellToolbarLocation" = {
          default = "right";
          jupyter-notebook = "left";
        };

        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "${pkgs.nil}/bin/nil";
        "nix.serverSettings" = {
          nil = {
            formatting.command = [ "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt" ];
          };
        };

        "npm.fetchOnlinePackageInfo" = false;

        "python.analysis.autoImportCompletions" = true;
        "python.analysis.stubPath" = "./typings/";
        "python.defaultInterpreterPath" = "${pkgs.python3}/bin/python";
        "python.linting.enabled" = false;
        "python.showStartPage" = false;

        "redhat.telemetry.enabled" = false;

        "scm.alwaysShowProviders" = true;

        "security.workspace.trust.banner" = "never";

        "telemetry.telemetryLevel" = "off";

        "typescript.updateImportsOnFileMove.enabled" = "always";

        "update.mode" = "none";
        "update.showReleaseNotes" = false;

        "vscode-neovim.neovimPath" = "${pkgs.neovim}/bin/nvim";

        "vsintellicode.modify.editor.suggestSelection" = "automaticallyOverrodeDefaultValue";

        "window.menuBarVisibility" = "toggle";
        "window.titleBarStyle" = "native";

        "workbench.colorTheme" = "Dracula";
        "workbench.editorAssociations" = {
          "*.ipynb" = "jupyter-notebook";
        };
        "workbench.enableExperiments" = false;
        "workbench.settings.enableNaturalLanguageSearch" = false;

        "yaml.format.enable" = false;

      };
    };

    ssh = {
      enable = true;
      controlMaster = "autoask";
      controlPath = "~/.ssh/connections/%r@%h:%p";
      controlPersist = "10m";
      matchBlocks = {
        "*git*" = {
          extraOptions = {
            ControlMaster = "no";
            ControlPersist = "no";
          };
        };
      };
    };

    thunderbird = {
      enable = true;
      profiles.main = {
        isDefault = true;
        withExternalGnupg = true;
      };
    };

  };


  services = {

    gpg-agent = {
      defaultCacheTtl = 1800;
      enable = true;
      enableExtraSocket = true;
      enableScDaemon = true;
      enableSshSupport = true;
      enableZshIntegration = true;
      pinentryPackage = pkgs.pinentry-qt;
    };

    # manual login required
    nextcloud-client.enable = true;

    # manual config required
    syncthing = {
      enable = true;
      tray.enable = true;
    };

  };


  # TODO accounts.email.accounts (current: manual config)


  # ======================================


  # hotfix because GUI is managed on system level (fow now)
  systemd.user.targets.tray = {
    Unit = {
      Description = "Home Manager System Tray";
      Requires = [ "graphical-session-pre.target" ];
    };
  };

  # allow unfree limited
  nixpkgs.config.allowUnfree = false;
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    # mpv plugins missing licenses
    "evafast"
  ];


  # ZSH config

  programs.zsh.enable = true;
  programs.zsh.antidote = {
    enable = true;
    plugins = [
      "djui/alias-tips"
    ];
  };
}
