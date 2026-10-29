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

  # userMcp also configured in specific modules
  userMcp.servers = {
    # TODO make dependent on osConfig trilium enabled
    trilium-notes = {
      type = "http";
      url = "http://127.0.0.1:37840/mcp";
    };
  };

  userSettings = {

    "chat.byokUtilityModelDefault" = "mainAgent";
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
