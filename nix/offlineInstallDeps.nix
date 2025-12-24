# "offline-installation dependencies"
# collection of dependencies required for disko-install-menu offline installations for this flake due this flake’s weirdness
# TODO integrate into officially supported buildDependencies option supplied by disko-install-menu.nixosModules.support
{ pkgs, ... }:
{
  system.extraDependencies = with pkgs; [
    shellcheck
  ];
}
