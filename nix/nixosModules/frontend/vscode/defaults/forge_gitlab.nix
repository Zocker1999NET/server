{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.attrsets) genAttrs;
  inherit (lib.lists) singleton;
  inherit (lib.options) mkOption;
  cfg = config.gitlab;
in
{

  # _class = "homeManager.vscodeProfile";

  options.gitlab = {

    domains = mkOption {
      description = "GitLab domains for which to configure the GitLab MCP server in VS Code.";
      type = with types; listOf str;
      default = singleton "gitlab.com";
      example = [
        "gitlab.com"
        "gitlab.example.com"
      ];
    };

  };

  config = {

    # GitLab instances used by the user
    gitlab.domains = [
      "gitlab.com"
      "gitlab.kit.edu"
    ];

    extensions = with pkgs.vscode-extensions; [
      gitlab.gitlab-workflow
    ];

    # configure the GitLab MCP server for each supported domain
    # see https://docs.gitlab.com/user/model_context_protocol/mcp_server/
    userMcp.servers = genAttrs cfg.domains (domain: {
      type = "http";
      url = "https://${domain}/api/v4/mcp";
      headers."X-Gitlab-Mcp-Server-Tool-Name-Prefix" = "${domain}_";
    });

    # reference: https://docs.gitlab.com/editor_extensions/visual_studio_code/settings/#extension-settings
    userSettings = {

      # disable all Duo features on outside projects (preferring VSCode Copilot)
      "gitlab.duo.enabledWithoutGitlabProject" = false;

      # disable Duo code suggestions, have no subscription
      # and prevent conflict with GitHub Copilot Inline Suggestions
      "gitlab.duoCodeSuggestions.enabled" = false;

      # disable hints for GitLab Duo
      "gitlab.keybindingHints.enabled" = false;

      # notify when a pipeline completes
      "gitlab.showPipelineUpdateNotifications" = true;

    };

  };

}
