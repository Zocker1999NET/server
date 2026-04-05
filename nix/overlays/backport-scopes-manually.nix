{ lib, ... }@flakeArg:
{ pkgs_unstable, ... }@systemArg:
final: prev: {
  # has no overrideScope
  vscode-extensions = prev.vscode-extensions // {
    rooveterinaryinc = prev.vscode-extensions.rooveterinaryinc // {
      inherit (pkgs_unstable.vscode-extensions.rooveterinaryinc) roo-cline;
    };
  };
}
