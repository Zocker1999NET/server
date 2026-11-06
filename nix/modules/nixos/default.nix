{
  _class = "flake";
  # WARNING: there is still the legacy directory & output nixosModules which is used in parallel!
  flake.modules.nixos = rec {

    # public modules

    flakeReflectRevision = ./flakeReflectRevision.nix;
    flakeSuppressRevision = ./flakeSuppressRevision.nix;

    # usage classes
    interactiveAppliance = ./interactiveAppliance.nix;
    interactiveClient = ./interactiveClient.nix;
    interactiveDevice = ./interactiveDevice.nix;

  };
}
