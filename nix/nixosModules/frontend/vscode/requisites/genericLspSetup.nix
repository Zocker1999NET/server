{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
in
{

  # _class = "homeManager.vscodeProfile";

  options.genericLspProxy = mkOption {
    description = ''
      Generic LSP server configuration for vscode-generic-lsp-proxy.

      Must be configured specifically for each IDE module.

      See [quickstart](https://github.com/mjmorales/vscode-generic-lsp-proxy#-quick-start)
      or [configuration schema](https://github.com/mjmorales/vscode-generic-lsp-proxy#configuration-schema).
    '';
    type = types.submodule {
      freeformType = types.json;
      options = {

        languageId = mkOption {
          description = "Unique identifier for the language.";
          type = types.str;
          example = "python";
        };

        command = mkOption {
          description = "Command to start the LSP server.";
          type = types.str;
          example = "pylsp";
        };

        fileExtensions = mkOption {
          description = "File extensions to activate this server.";
          type = with types; listOf str;
          example = [ ".py" ];
        };

        args = mkOption {
          description = "Command line arguments.";
          type = with types; listOf str;
          default = [ ];
          example = [ "--stdio" ];
        };

        filePatterns = mkOption {
          description = "Glob patterns for file matching.";
          type = with types; listOf str;
          default = [ ];
          example = [ "**/*.py" ];
        };

        workspacePattern = mkOption {
          description = "Restrict to specific workspace folders.";
          type = with types; nullOr str;
          default = null;
          example = "^foo/bar$";
        };

        initializationOptions = mkOption {
          description = "LSP initialization options.";
          type = types.attrs;
          default = { };
          example.preferences.includeCompletionsForModuleExports = true;
        };

        settings = mkOption {
          description = "Language-specific settings.";
          type = types.attrs;
          default = { };
          example.pylsp.plugins.pycodestyle = {
            enabled = true;
            maxLineLength = 120;
          };
        };

        env = mkOption {
          description = "Environment variables.";
          type = with types; attrsOf str;
          default = { };
          example.LSP_HOME = "/path/to/home";
        };

        transport = mkOption {
          description = "Connection type.";
          type = types.enum [
            "stdio"
            "tcp"
            "websocket"
          ];
          default = "stdio";
          example = "tcp";
        };

        tcpPort = mkOption {
          description = "Port for TCP transport. Only used when transport is tcp.";
          type = with types; nullOr port;
          default = null;
          example = 6005;
        };

        websocketUrl = mkOption {
          description = "URL for WebSocket transport. Only used when transport is websocket.";
          type = with types; nullOr str;
          default = null;
          example = "ws://localhost:8080";
        };

      };
    };
  };

  config = {

    extensions = with pkgs.nix-vscode-extensions.vscode-marketplace-release; [
      # cSpell:disable
      mjmorales.generic-lsp-proxy
      # cSpell:enable
    ];

    userSettings."genericLspProxy.configPath" =
      pkgs.writers.writeJSON "generic-lsp-proxy.json" config.genericLspProxy;

  };

}
