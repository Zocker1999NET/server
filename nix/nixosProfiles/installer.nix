# applies to self-built installers, esp. auto installers

{ inputs, ... }@flakeArg:
{
  config,
  lib,
  modulesPath,
  ...
}:
{

  _class = "nixos";

  imports = [
    # from nixpkgs
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" # includes allHardware configs
    # from flake inputs
    inputs.disko-install-menu.nixosModules.default
    # from here
    ./common.nix
    ./pveGuestHwSupport.nix # also for guest agent, serial out, ...
  ];

  config = {
    isoImage = {
      squashfsCompression = "zstd"; # more efficient
    };
    networking.domain = lib.mkDefault "temp.6nw.de"; # acceptable here because temporary
    system.stateVersion = lib.versions.majorMinor config.system.nixos.version;
    # installer does not necessarily need working SSH access & an extra user for that

    # TODO upstream
    security.sudo-rs.wheelNeedsPassword = false;
  };

}
