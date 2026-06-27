{
  pkgs,
  ...
}:
{

  # _class = "homeManager.vscodeProfile";

  extensions = with pkgs.vscode-extensions; [
    # github.copilot is the deprecated predecessor
    github.copilot-chat
  ];

  # userMcp configured in specific modules

  userSettings = {

    "chat.disableAIFeatures" = false;
    "chat.tools.urls.autoApprove" = {
      # sorted alphabetically by reversed domain
      "https://github.com/microsoft/vscode/wiki/*" = true;
      "https://docs.github.com" = true;
      "https://code.visualstudio.com" = true;
      "https://nixos.org/manual" = true;
      "https://wiki.nixos.org" = true;
    };
    "chat.utilityModel" = "customendpoint/kit.gpt-oss-120b";
    "chat.utilitySmallModel" = "customendpoint/kit.gpt-oss-120b";
    "chat.viewSessions.orientation" = "stacked";

    "inlineChat.askInChat" = false;

  };

}
