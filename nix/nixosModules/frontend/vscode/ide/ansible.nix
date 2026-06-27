{
  pkgs,
  ...
}:
{

  # _class = "homeManager.vscodeProfile";

  imports = [
    ./python.nix
  ];

  extensions = with pkgs.vscode-extensions; [
    redhat.ansible # requires: ms-python.vscode-python-envs, redhat.vscode-yaml
    redhat.vscode-yaml
  ];

  userSettings = {
    # fuck you RedHat for prompting sign in to an optional feature
    # until you find a non-obviously setting to disable it!
    # pls fix https://github.com/ansible/vscode-ansible/issues/879 thx
    "ansible.lightspeed.enabled" = false;
    "ansible.lightspeed.suggestions.enabled" = false;
    "ansible.mcpServer.enabled" = true;
    # (paths for Ansible tooling not configured, use devShell)

    "yaml.format.enable" = false;
  };

}
