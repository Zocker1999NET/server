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
  inherit (lib.lists) forEach;
  inherit (lib.meta) getExe;
  inherit (lib.modules)
    mkAfter
    mkIf
    mkMerge
    mkOrder
    ;
  inherit (lib.strings) getName;
  # homeManager lib
  inherit (lib.hm) dag;
  mkHomeDirSymlink = path: mkOutOfStoreSymlink "${config.home.homeDirectory}/${path}";
  myOpts = osConfig.x-banananetwork;
in
{

  _class = "homeManager";

  # TODO configure plasma via github:nix-community/plasma-manager

  imports = [
    ./antidote-omz.nix
    ./home-develop.nix
  ];

  home.file = {

    # TODO sptlrx player detection broken because ".instanceXXXX" suffixes
    #   v1.2.2 fixes this, but its test requires network, making it hard to package for NixOS
    ".config/sptlrx/config.yaml".text = lib.generators.toYAML { } {
      player = "mpris";
      timerInterval = 200;
      updateInterval = 2000;
      mpris.players = [ "ncspot" ];
    };

    ".ssh/connections/.keep".text = ''
      # created by home-manager (to create directory)
    '';

    # User files

    "Documents/Ablagen".source = mkHomeDirSymlink "Nextcloud/Dokumente/Ablagen";
    "Documents/Scans".source = mkHomeDirSymlink "Nextcloud/Dokumente/Scans";

  };

  home.packages = with pkgs; [

    # media
    ncspot
    sptlrx # spotify subtitle generator
    # TODO server with: your_spotify

    # tools
    brightnessctl
    cowsay # for bofh_cow
    jdupes
    libnotify # for zsh-auto-notify
    pdfgrep # for scansystem
    pdfpagecount
    (writeShellApplication {
      # TODO extract as helper function/derivation
      # (I do not use module, as I see its config as user-data)
      name = "task";
      runtimeInputs = [
        # required by my plugins
        python3
      ];
      meta = pkgs.taskwarrior3.meta;
      text = ''exec ${getExe taskwarrior3} "$@"'';
    })
    (mkIf osConfig.services.wayland.enable wl-clipboard)

    ## calculators
    ipv6calc # IPv4/IPv6 swiss kit
    kalker # advanced calculator
    pcalc # programmer’s calculator
    rink # unit aware calculator
    subnetcalc # IPv4/IPv6 subnet info parser
    (writeShellApplication {
      # TODO extract as helper function/module
      name = "calc"; # tool group
      text = ''
        echo "you probably mean either:"
        echo "- ipv6calc # IPv4/IPv6 swiss kit"
        echo "- kalker # advanced calculator"
        echo "- pcalc # programmer’s calculator"
        echo "- rink # unit aware calculator"
        echo "- subnetcalc # IPv4/IPv6 subnet info parser"
      '';
    })

    # UI (mostly require manual setup)
    anki # requires fonts listed below
    bibletime
    element-desktop
    kdePackages.filelight
    kdePackages.kleopatra
    kdePackages.yakuake
    keepassxc
    (mkIf osConfig.services.tailscale.enable ktailctl) # Tailscale GUI client
    krita
    libreoffice-qt6-fresh # "qt6" for KDE Plasma; "fresh" to get newer features
    streamlined-client # TODO manual required: xdg-settings set default-url-scheme-handler entertainment-decider streamlined-client_uri.desktop
    wireshark
    tor-browser
    trilium-desktop
    xournalpp
    yubikey-manager
    yubioath-flutter

    # Gaming
    sc-controller # userspace driver (manual start/stop)

    # Wine for e.g. Starcraft 2
    # https://wiki.nixos.org/wiki/Battle.net
    # deriving that wineWow64Packages.stagingFull is equivalent or "better" to what the wiki suggests
    # while being built by Hydra and thus being cached by cache.nixos.org
    # see https://github.com/NixOS/nixpkgs/blob/74cc63f702f7d60a557e152a57b40fb1fd0f72ac/pkgs/top-level/wine-packages.nix#L41
    wineWow64Packages.stagingFull
    winetricks

    # fonts (require fonts.fontconfig.enable)
    fira
    nerd-fonts.fira-code
    nerd-fonts.hasklug
    ## for Anki decks
    kochi-substitute # "Kochi Mincho" for Japanese decks

  ];

  programs = {

    autojump = {
      # for doc, see https://github.com/wting/autojump
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };

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
      icons = "auto";
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
      tmux = {
        enableShellIntegration = false; # IMO less optimal than without
      };
    };

    git = {
      enable = true;
      settings =
        let
          inherit (config.programs) vscode;
        in
        {
          diff = {
            tool = mkIf vscode.enable "vscode";
          };
          difftool = {
            prompt = false;
          };
          "difftool \"vscode\"" = mkIf vscode.enable {
            cmd = "${getExe vscode.package} --wait --diff $LOCAL $REMOTE";
          };
          user = {
            email = "felix.stupp@banananet.work";
            name = "Felix Stupp";
          };
        };
      signing = {
        key = myOpts.gpgSignatureKey.fingerprint;
        signByDefault = true;
      };
    };

    # GitHub CLI
    gh = {
      enable = true;
      extensions = with pkgs; [
        gh-f # ultimate fzf (search) integration
        gh-poi # for purging branches assigned to closed PRs
        gh-review-conductor # for applying review comments & suggestions locally
        gh-stack # for using stacked PRs
      ];
      gitCredentialHelper.enable = false; # prefer SSH
      hosts."github.com".user = "Zocker1999NET";
      settings = {
        git_protocol = "ssh";
        telemetry = "disabled";
      };
    };

    gpg = {
      enable = true;
      mutableKeys = false;
      mutableTrust = false;
      publicKeys = forEach myOpts.gpgTrustedKeys (key: {
        source = key.output;
        trust = 5;
      });
      scdaemonSettings = {
        disable-ccid = mkIf osConfig.services.pcscd.enable true;
      };
    };

    mergiraf = {
      enable = true;
      enableGitIntegration = true;
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
        # == user interface
        osd-font = "Bitstream Vera Sans"; # in case no default font is given by GTK/…
        screenshot-format = "png";
        # == video playback
        vo = "gpu";
        hwdec = "auto-safe";
        gpu-context = "wayland";
        # == audio playback
        # because mpv does 5.1 down mix to 2.1 not correctly, these options might help
        # 5.1 Test Audio: https://www.youtube.com/watch?v=q9eKLPCciWw
        # uses ffmpeg filter to down mix 5.1 / 7.1 to 2.1 correctly
        af = ''lavfi="pan=stereo|FL < 0.5*FC + 0.3*FLC + 0.3*FL + 0.3*BL + 0.3*SL + 0.5*LFE | FR < 0.5*FC + 0.3*FRC + 0.3*FR + 0.3*BR + 0.3*SR + 0.5*LFE",lavfi="acompressor=6"'';
        # alternative: uses ffmpeg filter to normalize volumes (not really fixing downmix, but might be an easy fix)
        #af=lavfi=[loudnorm=I=-16:TP=-3:LRA=4]
        # alternative: uses ffmpeg filter to normalize volumes (not really fixing downmix, but might be an easy fix)
        #af=drc=2
        # == playback settings
        save-position-on-quit = true;
        speed = 1.2;
        # == youtube-dl / yt-dlp settings
        ytdl-format = "ytdl"; # use yt-dlp config
        # == caching
        prefetch-playlist = true;
        cache = "auto";
        demuxer-thread = true;
        demuxer-readahead-secs = 15;
        demuxer-max-bytes = "512MiB";
        demuxer-max-back-bytes = "64MiB";
      };
      profiles =
        let
          filename = ''get("filename", "DEFAULT"):lower()'';
          multiMatching =
            input: patterns:
            "(${concatStringsSep " or " (map (pat: "${input}:match(${pat})") patterns)}) ~= nil";
          extensionMatching = input: extensions: multiMatching input (map (ext: "\"%.${ext}$\"") extensions);
        in
        {
          music = {
            profile-desc = "for Music";
            profile-cond = extensionMatching filename [
              "flac"
              "m4a"
              "mp3"
              "opus"
            ];
            profile-restore = "copy-equal";
            audio-display = "no";
            speed = 1;
          };
          tv_series = {
            profile-desc = "for TV Series";
            profile-cond = multiMatching filename [
              ''"s%d+e%d+"''
              ''"%(%d+%)"''
            ];
            profile-restore = "copy-equal";
            speed = 1;
          };
        };
      scripts = with pkgs.mpvScripts; [
        autoload # "autoplay" files in same dir
        evafast # VHC rewind effect
        modernx-zydezu # modern OSC
        mpris
        mpv-cheatsheet-ng # see all keybindings, use ?
        quack # fade volume on seek
        quality-menu # select quality on yt-dlp streaming
        reload # reload on connection-loss
        sponsorblock
        thumbfast # thumbnails on modernx
      ];
      scriptOpts =
        let
          scriptNames = map (p: getName p) config.programs.mpv.scripts;
          mkIfScript = name: mkIf (builtins.elem name scriptNames);
        in
        {
          modernx = {
            # order by README (https://github.com/zydezu/ModernX#configurable-options)
            # general
            welcomescreen = true;
            # interface
            persistentprogress = false; # tested, mostly irritating instead of useful
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
            local_pattern = (mkIf config.programs.yt-dlp.enable "[%s_-]%[([%w-_]+)%]%.[mw][kpe][v4b]m?$"); # tuned for yt-dlp default
          };
        };
    };

    retroarch = {
      enable = true;
      cores = {
        _1983-NES.enable = true;
        _1989-GB.enable = true;
        _1990-SNES.enable = true;
        _1996-N64.enable = true;
        _1998-GBC.enable = true;
        _2001-GBA.enable = true;
        _2001-GCN.enable = true;
        _2004-NDS.enable = true;
        _2006-Wii.enable = true;
      };
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        "*" = {
          ControlMaster = "auto";
          ControlPath = "~/.ssh/connections/%r@%h:%p";
          ControlPersist = "10m";
          ForwardAgent = false;
          HashKnownHosts = false;
          ServerAliveInterval = 0;
          ServerAliveCountMax = 3;
        };
        "*git*" = dag.entryBefore [ "*" ] {
          ControlMaster = "no";
          ControlPersist = "no";
        };
      };
    };

    texlive = {
      enable = true;
      # TODO filter hard to save storage
      extraPackages = tpkgs: { inherit (tpkgs) scheme-full; };
    };

    thunderbird = {
      enable = true;
      profiles.main = {
        isDefault = true;
        settings = {
          "mail.compose.attachment_reminder_keywords" = concatStringsSep "," [
            # file suffixes
            ".doc"
            ".docx"
            ".log"
            ".pdf"
            ".pps"
            ".ppt"
            ".pptx"
            ".rtf"
            ".txt"
            ".xls"
            ".xlsx"
            # English
            "attach"
            "attachment"
            "attached"
            "attaching"
            "CV"
            "cover letter"
            "enclosed"
            # German
            "Anhang"
            "angehangen"
            "angehängt"
            "angehängte"
            "angehängtes"
            "anhängen"
          ];
          "mailnews.display.html_as" = 1; # render "Message Body As" = "Plain Text"
          "privacy.globalprivacycontrol.enabled" = true;
        };
        withExternalGnupg = true;
      };
    };

    yt-dlp = {
      enable = true;
      settings = {
        # TODO make dependent on AV1 hw support
        compat-options = "prefer-vp9-sort"; # no support for AV1 so far
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
      pinentry.package = pkgs.pinentry-qt;
    };

    # manual pairing required
    kdeconnect = {
      enableSettings = true;
      settings.customDevices = [
        "100.99.238.6" # iehpc094a
        "100.110.59.63" # zockerfair
        "100.66.96.36" # zockerpc
      ];
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

  # ZSH config

  programs.zsh = {
    enable = true;
    # TODO configure dotDir = ".config/zsh"; (most probably requires or wants to be synced with system-level config)
    antidote = {
      enable = true;
      ohMyZsh.enable = true;
      # lists of plugins:
      # - https://github.com/unixorn/awesome-zsh-plugins
      plugins = [
        "djui/alias-tips"
        "zpm-zsh/ls"
        "aoyama-val/zsh-delete-prompt" # ($ cmd -> cmd)
        "ianthehenry/zsh-autoquoter" # applied to last arg
        "Zocker1999NET/zsh-gtr" # git tag release
        # blocked until urgency can be configured or is !=critical
        # (making Plasma to ignore auto timeout time)
        # see https://github.com/MichaelAquilina/zsh-auto-notify/issues/26
        # or https://github.com/MichaelAquilina/zsh-auto-notify/pull/24
        # or https://github.com/MichaelAquilina/zsh-auto-notify/pull/49
        #"MichaelAquilina/zsh-auto-notify" # notify on long tasks
        "zpm-zsh/clipboard" # clipboard integration
        "mtxr/zsh-change-case" # change case widget
        "fundor333/bofh" # BOFH fortune quotes
      ];
      useFriendlyNames = false; # for plugin cache dir
    };
    # order from https://home-manager-options.extranix.com/?query=programs.zsh.initContent&release=release-25.05
    initContent = mkMerge [
      # 500: early initialization
      # 550: before completion initialization
      # 1000: General configuration
      # for configuring everything else
      (mkOrder 1050 ''
        functions[prompt_hg]=""

        # misc configs
        export ANSIBLE_NOCOWS=1

        # zsh-autoquoter: auto-quote arguments to certain commands
        ZAQ_PREFIXES=(
          'git commit( [^ ]##)# -[^ -]#m'
          # do not match ssh, is more bad than good
          #'ssh( -[^ ]##)# [^ -][^ ]#'
        )
        # add to syntaxHighlighting, which should enabled in system config (progams.zsh.syntaxHighlightning)
        ZSH_HIGHLIGHT_HIGHLIGHTERS+=(zaq)

        # zsh-change-case: change word case (Ctrl+K+U upper, Ctrl+K+L lower)
        bindkey -r '^K'  # unbind Ctrl+K first to avoid conflicts
        bindkey '^K^U' _mtxr-to-upper
        bindkey '^K^L' _mtxr-to-lower

        # zsh-delete-prompt: delete prompt text from current line (useful for pasted commands)
        bindkey "^[d" delete-prompt  # Alt+d

        # helper functions

        function mkcd() {
          mkdir --parents "$1" && cd "$1";
        }

        function readme() {
          EDITOR="''${EDITOR:=editor}";
          f=$(/usr/bin/env ls --indicator-style=slash . | grep --perl-regexp --ignore-case '^readme(\.(md|txt))?$' | sort | head --lines=1);
          "$EDITOR" "''${f:=README.md}";
        }
        function todo() {
          EDITOR="''${EDITOR:=editor}";
          f=$(/usr/bin/env ls --indicator-style=slash . | grep --perl-regexp --ignore-case '^todo(\.(md|txt))?$' | sort | head --lines=1);
          "$EDITOR" "''${f:=TODO.md}";
        }

        function fork() {
          "$@" >/dev/null 2>&1 &!;
        }
      '')
      # 1500: Last to run configuration
    ];
    oh-my-zsh = {
      # only load directly when antidote does not load them
      enable = !(with config.programs.zsh.antidote; enable && ohMyZsh.enable);
      extraConfig = ''
        MAGIC_ENTER_GIT_COMMAND='git status -u .'
        MAGIC_ENTER_OTHER_COMMAND='ls -lh .'

        if [[ -o login ]]; then
          ZSH_TMUX_AUTOSTART=false
        else
          ZSH_TMUX_AUTOSTART=true
          ZSH_TMUX_AUTOCONNECT=false
          ZSH_TMUX_AUTOQUIT=true
        fi

        # To remove alias "ls=ls --color=tty" by oh-my-zsh for exa alias
        DISABLE_LS_COLORS="true"
        # disable oh-my-zsh plugin updates (loaded directly from nixpkgs)
        zstyle ':omz:update' mode disabled
      '';
      plugins = mkMerge [
        [
          "colorize" # command on-call
          "command-not-found" # also works on NixOS
          "common-aliases"
          "dirhistory" # Alt+<ArrowKey> navigation on directories
          # aliases / completion for specific apps (TODO conditional)
          "git"
          "man"
          "nmap"
          "systemd"
          "tailscale"
          "tmux"
          "vscode"
        ]
        # stoped working when loaded before some antidote plugins
        (mkAfter [ "magic-enter" ])
      ];
      theme = "agnoster";
    };
    shellAliases = mkMerge [
      {
        # shell meta helpers
        echo-args = "${getExe pkgs.python3} -c 'import sys; print(sys.argv[1:])'";
        launch = "fork";
        # file management
        resolve = ''cd "$(pwd -P)"'';
        tree = "eza --tree";
        # OS mgmt
        please = "sudo";
        swapclear = "sudo swapoff -a && sudo swapon -a";
        # tmux
        tnw = "tmux new-window";
        tsv = "tmux split -v";
        tsh = "tmux split -h";
      }
      # replacements for ls aliases from oh-my-zsh plugin common-aliases
      # (some of them do not apply one-to-one to eza)
      # https://github.com/ohmyzsh/ohmyzsh/blob/9e2c1548c3dfeefd055e1c6606f66657093ae928/plugins/common-aliases/common-aliases.plugin.zsh
      (mkIf config.programs.eza.enable {
        l = "eza --long --classify=automatic --header";
        la = "eza --long --almost-all --classify=automatic --header";
        lr = "eza --long --recurse --sort=modified --classify=automatic --header";
        lt = "eza --long --sort=modified --classify=automatic --header";
        ll = "eza --long";
        ldot = "eza --only-dirs --all";
        lS = "eza --long --oneline --sort=size --classify=automatic --blocksize";
        lart = "eza --oneline --classify=automatic --all --reverse --sort=modified";
        lrt = "eza --oneline --classify=automatic --reverse --sort=modified";
        lsr = "eza --long --all --recurse --classify=automatic --header";
        lsn = "eza --oneline";
      })
      # extending git aliases from oh-my-zsh plugin git
      (mkIf config.programs.git.enable {
        grbas = "git rebase --autosquash";
        grbias = "git rebase --interactive --autosquash";
      })
    ];
    shellGlobalAliases = {
      U = "|& up";
    };
  };

}
