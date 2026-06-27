{
  pkgs,
  ...
}:
{
  # _class = "homeManager.vscodeProfile";
  extensions = with pkgs.vscode-extensions; [
    svelte.svelte-vscode
  ];
}
