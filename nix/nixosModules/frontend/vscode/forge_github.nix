{
  pkgs,
  ...
}:
{

  # _class = "homeManager.vscodeProfile";

  extensions = with pkgs.vscode-extensions; [
    github.vscode-github-actions
    github.vscode-pull-request-github
  ];

  userSettings = {

    "github.gitAuthentication" = false; # prefer native SSH for that
    "github.gitProtocol" = "ssh";

    # define langs for which GitHub Issues should not trigger
    # (i.e. languages where `#` is used frequently)
    "githubIssues.ignoreCompletionTrigger" = [
      # default
      "coffeescript"
      "crystal"
      "diff"
      "dockerfile"
      "dockercompose"
      "ignore"
      "ini"
      "julia"
      "makefile"
      "perl"
      "powershell"
      "python"
      "r"
      "ruby"
      "shellscript"
      "yaml"
      # non-default
      "nix"
    ];

  };

}
