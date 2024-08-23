{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.x-banananetwork.debugMinimal;
in
{

  options = {

    x-banananetwork.debugMinimal = {

      enable = lib.mkEnableOption ''
        a set of opionated options to make systems a little bit easier to debug.
      '';

    };

  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      jq # JSON
      pv
    ];

    programs = {

      bash = {
        enableCompletion = true;
        enableLsColors = true;
        vteIntegration = true;
      };

      htop = {
        enable = true;
        settings = {
          hide_kernel_threads = true;
          hide_userland_threads = true;
        };
      };

      neovim = {
        enable = true;
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;
        configure = {
          customRC = ''
            set shiftwidth=2 expandtab tabstop=8 softtabstop=0
          '';
        };
      };

      tmux = {
        aggressiveResize = true;
        clock24 = true;
        customPaneNavigationAndResize = true;
        enable = true;
        extraConfig = ''
          # Enable true color support
          set-option -ga terminal-overrides ",xterm*:Tc:smcup@:rmcup@"
          set-option -ga terminal-overrides ",screen*:Tc:smcup@:rmcup@"
          set-option -ga terminal-overrides ",tmux*:Tc:smcup@:rmcup@"
          # Enable mouse by default
          set-option -g mouse on
          # join pane shortcut
          unbind j
          bind-key j command-prompt -p "send pane to:"  "join-pane -t '%%'"
          # sync shortcut
          unbind Space
          #bind-key Space set-window-option synchronize-panes
          bind-key Space set-window-option synchronize-panes\; display-message "synchronize-panes is now #{?pane_synchronized,on,off}"
          # hide bar shortcut
          unbind h
          bind-key h set-option -g status
          # spawn new window
          unbind-key C
          unbind-key C-c
          bind-key C command-prompt -p "command:" "new-window -d '%%'"
          bind-key C-c command-prompt -p "command:" "new-window -d '%%'"
        '';
      };

    };

  };

}
