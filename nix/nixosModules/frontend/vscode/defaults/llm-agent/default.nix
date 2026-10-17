{
  pkgs,
  ...
}:
let
  # need to be updated when upstream model change
  codingModelName = "Alias: Medium Model (Local) (customendpoint)";
  utilityModelId = "customendpoint/alias.simple-local";
in
{

  # _class = "homeManager.vscodeProfile";

  imports = [
    ./approvedEdits.nix
    ./approvedUrls.nix
  ];

  extensions = with pkgs.vscode-extensions; [
    # github.copilot is the deprecated predecessor
    github.copilot-chat
  ];

  # userMcp configured in specific modules

  userSettings = {

    "chat.disableAIFeatures" = false;
    "chat.planAgent.defaultModel" = codingModelName;
    "chat.tools.terminal.blockDetectedFileWrites" = "outsideWorkspace";
    "chat.utilityModel" = utilityModelId;
    "chat.utilitySmallModel" = utilityModelId;
    "chat.viewSessions.orientation" = "stacked";

    "inlineChat.askInChat" = false;
    "inlineChat.defaultModel" = codingModelName;

  };

}
