# parts my frontend home-manager module only applicable to machines used for developing stuff (currently all)
{
  pkgs,
  ...
}:
{

  _class = "homeManager";

  imports = [
    ./vscode
  ];

  home.packages = with pkgs; [
    # cSpell:disable
    # editors
    neovim
    # general tools
    gnumake
    just
    # nix dev
    nix-output-monitor
    # cSpell:enable
  ];

  programs = {

    direnv = {
      enable = true;
      config = {
        global = {
          hide_env_diff = false;
          strict_env = true;
        };
      };
      enableBashIntegration = false; # explicitly disable for bash so bash can be a fallback for that
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

  };

}
