{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  inherit (builtins) concatStringsSep;
  inherit (config.lib.file) mkOutOfStoreSymlink;
  mkHomeDirSymlink = path: mkOutOfStoreSymlink "${config.home.homeDirectory}/${path}";
  myGpgKey = pkgs.fetchurl {
    url = "https://keys.openpgp.org/vks/v1/by-fingerprint/73D09948B2392D688A45DC8393E1BD26F6B02FB7";
    hash = "sha256-tbRDhXZJk2aBIF4Ed0HIR8jalxnPJDNziBy51I9Awxs=";
  };
  archiveGpgKey = pkgs.fetchurl {
    url = "https://keys.openpgp.org/vks/v1/by-fingerprint/19C17AF30A1152D473A3849C28279F3E0A444E63";
    hash = "sha256-k81wvlyx3oUJjKx1Dpmas1LLvTwKW8FN4MEbOvfRyj8=";
  };
in
{

  home.stateVersion = osConfig.system.stateVersion;

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

    # User files

    "Documents/Ablagen".source = mkHomeDirSymlink "Nextcloud/Dokumente/Ablagen";
    "Documents/Scans".source = mkHomeDirSymlink "Nextcloud/Dokumente/Scans";

  };

  home.packages = with pkgs; [

    # dev
    neovim

    # media
    ncspot
    sptlrx # spotify subtitle generator
    # TODO server with: your_spotify

    # dev
    nix-output-monitor

    # tools
    fzf # fuzzy finder  # TODO integrate better: https://home-manager-options.extranix.com/?query=fzf&release=master
    ipv6calc # IPv4/IPv6 swiss kit
    jdupes
    kalker # advanced calculator
    pcalc # programmer’s calculator
    rink # unit aware calculator
    subnetcalc # IPv4/IPv6 subnet info parser
    (lib.mkIf osConfig.services.wayland.enable wl-clipboard)

    # UI
    element-desktop
    kdePackages.filelight
    kdePackages.kleopatra
    keepassxc
    krita
    libreoffice-qt6-fresh # "qt6" for KDE Plasma; "fresh" to get newer features
    wireshark
    tor-browser
    trilium-desktop
    xournalpp
    yubikey-manager
    yubioath-flutter

    # Dev Tools
    gnumake
    just

    # Gaming
    steamcontroller # userspace driver (manual start/stop)

    # utilities
    fira
    (pkgs.nerdfonts.override {
      fonts = [
        "FiraCode"
        "Hasklig"
      ];
    })

  ];

  programs = {

    bash = {
      enable = true;
      enableCompletion = true;
      historyControl = [
        "ignoredups"
        "erasedups"
        "ignorespace"
      ];
    };

    bat = {
      enable = true;
      extraPackages = with pkgs.bat-extras; [
        batdiff
        batwatch
        prettybat # format code before
      ];
    };

    chromium = {
      commandLineArgs = [
        "--no-default-browser-check"
        "--no-first-run"
        "--no-service-autorun" # just in case
        "--use-system-default-printer" # instead of least recently used
      ];
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
      extraConfig =
        let
          inherit (config.programs) vscode;
        in
        {
          diff = {
            tool = lib.mkIf vscode.enable "vscode";
          };
          difftool = {
            prompt = false;
          };
          "difftool \"vscode\"" = lib.mkIf vscode.enable {
            cmd = "${lib.getExe vscode.package} --wait --diff $LOCAL $REMOTE";
          };
        };
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
        {
          source = "${myGpgKey}";
          trust = 5;
        }
        {
          source = "${archiveGpgKey}";
          trust = 5;
        }
      ];
      scdaemonSettings = {
        disable-ccid = lib.mkIf osConfig.services.pcscd.enable true;
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
        # video: move
        Alt+Shift+LEFT add video-pan-x 0.01
        Alt+Shift+RIGHT add video-pan-x -0.01
        Alt+Shift+UP add video-pan-y 0.01
        Alt+Shift+DOWN add video-pan-y -0.01
        # video: resize
        Alt++ ignore
        Alt+- ignore
        Alt+SHARP add video-zoom 0.01
        Alt++ add video-zoom 0.01
        Alt+- add video-zoom -0.01
        # video: rotate
        r cycle_values video-rotate 90 180 270 0
        R cycle_values video-rotate 270 180 90 0
        # audio
        Shift+m af toggle "lavfi=[pan=1c|c0=0.5*c0+0.5*c1]" ; show-text "Audio mix set to Mono"
        # playback speed (make keys more sane)
        [ ignore
        ] ignore
        [ add speed -0.05
        ] add speed 0.05
        { ignore
        } ignore
        { add speed -0.2
        } add speed 0.2
        # misc
        + script-binding console/enable
      '';
      config = {
        save-position-on-quit = true;
        vo = "gpu";
        hwdec = "auto-safe";
        gpu-context = "wayland";
        alpha = "yes";
        speed = 1.2;
        #ytdl-format = "bestvideo[height<=?1080]+bestaudio/best";
        ytdl-format = "ytdl"; # use yt-dlp config
      };
      scripts = with pkgs.mpvScripts; [
        autoload # "autoplay" files in same dir
        evafast # VHC rewind effect
        modernx-zydezu # modern OSC
        mpris
        mpv-cheatsheet # see all keybindings, use ?
        quack # fade volume on seek
        quality-menu # select quality on yt-dlp streaming
        reload # reload on connection-loss
        sponsorblock
        thumbfast # thumbnails on modernx
      ];
      scriptOpts =
        let
          scriptNames = map (p: lib.getName p) config.programs.mpv.scripts;
          mkIfScript = name: lib.mkIf (builtins.elem name scriptNames);
        in
        {
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
          sponsorblock = {
            skip_categories = "sponsor,intro,outro,interaction,selfpromo";
            local_database = true;
            auto_update = true;
            skip_once = true;
            server_fallback = true;
            make_chapters = true;
            audio_fade = mkIfScript "quack" false; # quack does the same, but always
            fast_forward = false;
            # Lua pattern: https://www.lua.org/pil/20.2.html
            # TL;DR: '%' = '\', rest is as normal
            local_pattern = (lib.mkIf config.programs.yt-dlp.enable "[%s_-]%[([%w-_]+)%]%.[mw][kpe][v4b]m?$"); # tuned for yt-dlp default
          };
        };
    };

    retroarch = {
      enable = true;
      cores = with pkgs.libretro; [
        # as recommended by https://emulation.gametechwiki.com
        mesen # 1983 NES
        sameboy # 1989 GB
        bsnes-hd # 1990 SNES
        mupen64plus # 1996 N64 (multi, maybe for SNES too; not for NES)
        sameboy # 1998 GBC
        mgba # 2001 GBA
        dolphin # 2001 GCN
        melonds # 2004 NDS (+NDSi)
        dolphin # 2006 Wii
      ];
    };

    texlive = {
      enable = true;
      # TODO filter hard to save storage
      extraPackages = tpkgs: { inherit (tpkgs) scheme-full; };
    };

    vscode = {
      enable = true;
      enableExtensionUpdateCheck = config.programs.vscode.mutableExtensionsDir;
      enableUpdateCheck = false;
      extensions = with pkgs.vscode-extensions; [
        # general
        vscodevim.vim
        # IDE: Nix
        jnoortheen.nix-ide
        # IDE: Python
        ms-python.black-formatter
        ms-python.debugpy
        matangover.mypy
        # TODO (feature) maybe add isort, https://github.com/microsoft/vscode-isort, in nixpkgs
        # pylance does not work with VSCodium due to MSFT
        ms-pyright.pyright
        ms-python.python
      ];
      keybindingsNext = {
        # tabbing in *visually visible* order
        "ctrl+tab" = [
          {
            command = "-workbench.action.quickOpenNavigateNextInEditorPicker";
            when = "inEditorsPicker && inQuickOpen";
          }
          "-workbench.action.quickOpenPreviousRecentlyUsedEditorInGroup"
          "workbench.action.nextEditor"
        ];
        "ctrl+shift+tab" = [
          {
            command = "-workbench.action.quickOpenNavigatePreviousInEditorPicker";
            when = "inEditorsPicker && inQuickOpen";
          }
          "-workbench.action.quickOpenLeastRecentlyUsedEditorInGroup"
          "workbench.action.previousEditor"
        ];
        # disable overlappings from vim plugin
        "ctrl+p" = lib.singleton {
          command = "-extension.vim_ctrl+p";
          when = "editorTextFocus && vim.active && vim.use<C-p> && !inDebugRepl || vim.active && vim.use<C-p> && !inDebugRepl && vim.mode == 'CommandlineInProgress' || vim.active && vim.use<C-p> && !inDebugRepl && vim.mode == 'SearchInProgressMode'";
        };
      };
      mutableExtensionsDir = false;
      package = pkgs.vscodium;
      userSettings = {

        "[nix]" = {
          "editor.tabSize" = 2;
        };

        "[python]" = {
          "editor.defaultFormatter" = "ms-python.black-formatter";
        };

        "ansible.ansibleLint.path" = "${lib.getExe pkgs.ansible-lint}";

        "dev.containers.dockerComposePath" = "${lib.getExe pkgs.podman-compose}";
        "dev.containers.dockerPath" = "${lib.getExe pkgs.podman}";

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
        "mypy.dmypyExecutable" = "${pkgs.mypy}/bin/dmypy";
        "mypy.runUsingActiveInterpreter" = true;

        "notebook.cellToolbarLocation" = {
          default = "right";
          jupyter-notebook = "left";
        };

        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "${lib.getExe pkgs.nil}";
        "nix.serverSettings" = {
          nil = {
            formatting.command = [ (lib.getExe pkgs.nixfmt-rfc-style) ];
          };
        };

        "npm.fetchOnlinePackageInfo" = false;

        "python.analysis.autoImportCompletions" = true;
        "python.analysis.stubPath" = "./typings/";
        "python.defaultInterpreterPath" = lib.getExe pkgs.python3;
        "python.linting.enabled" = false;
        "python.showStartPage" = false;

        "redhat.telemetry.enabled" = false;

        "scm.alwaysShowProviders" = true;

        "security.workspace.trust.banner" = "never";

        "telemetry.telemetryLevel" = "off";

        "typescript.updateImportsOnFileMove.enabled" = "always";

        "update.mode" = "none";
        "update.showReleaseNotes" = false;

        "vscode-neovim.neovimPath" = lib.getExe pkgs.neovim;

        "vsintellicode.modify.editor.suggestSelection" = "automaticallyOverrodeDefaultValue";

        "window.menuBarVisibility" = "toggle";
        "window.titleBarStyle" = "native";

        "workbench.colorTheme" = "Default Dark Modern";
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
      controlMaster = "auto";
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

    yt-dlp = {
      enable = true;
      settings = {
        # format used by mpv for streaming
        format = concatStringsSep "/" [
          # prefer audio track in original language (e.g. YouTube)
          "bestvideo*+bestaudio[format_note*=original]"
          # otherwise use yt-dlp default
          "bestvideo*+bestaudio"
          "best"
        ];
        no-playlist = true; # only relevant if URL refers to video & playlist
        remux-video = "aac>m4a/mkv";
        sub-format = "ass/srt/best";
        sub-langs = "en.*,de.*,-live_chat";
        embed-subs = true;
        embed-thumbnail = true;
        embed-metadata = true; # includes: chapters & info-json
      };
    };

  };

  services = {

    gpg-agent = {
      defaultCacheTtl = 1800;
      enable = true;
      enableExtraSocket = true;
      enableScDaemon = true;
      # ssh-addkey needs to be done for every key manually, read man gpg-agent
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

  # syncthingtray typically starts to early to find the tray
  # TODO improve fix permanently
  systemd.user.services.syncthingtray.Service.ExecStartPre = "sleep 10";

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
  # TODO merge with nixos-modules/frontend/default.nix
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      # mpv plugins missing licenses
      "evafast"
    ];

  # ZSH config

  programs.zsh.enable = true;
  programs.zsh.antidote = {
    enable = true;
    plugins = [ "djui/alias-tips" ];
  };
}
