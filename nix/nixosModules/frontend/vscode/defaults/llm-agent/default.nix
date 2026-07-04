{
  pkgs,
  ...
}:
let
  # need to be updated when upstream model change
  codingModelName = "MiniMax M2.7 229B (customendpoint)";
  utilityModelId = "customendpoint/kit.gpt-oss-120b";
in
{

  # _class = "homeManager.vscodeProfile";

  extensions = with pkgs.vscode-extensions; [
    # github.copilot is the deprecated predecessor
    github.copilot-chat
  ];

  # userMcp configured in specific modules

  userSettings = {

    "chat.disableAIFeatures" = false;
    "chat.planAgent.defaultModel" = codingModelName;
    "chat.tools.urls.autoApprove" = {
      # sorted alphabetically by reversed domain
      "https://github.com/microsoft/vscode/wiki/*" = true;
      "https://docs.github.com" = true;
      "https://code.visualstudio.com" = true;
      "https://nixos.org/manual" = true;
      "https://wiki.nixos.org" = true;
    };
    "chat.utilityModel" = utilityModelId;
    "chat.utilitySmallModel" = utilityModelId;
    "chat.viewSessions.orientation" = "stacked";

    "inlineChat.askInChat" = false;
    "inlineChat.defaultModel" = codingModelName;

  };

}
