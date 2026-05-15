{
  config,
  importWithFlake,
  inputs,
  self,
  ...
}@flakeArg:
let
  nixpkgs = inputs.nixpkgs;
  nixosSystem =
    { modules, system }:
    let
      modsExtended = [
        self.modules.nixos.flakeReflectRevision
        self.outputs.nixosModules.myOptions
        self.nixosModules.withDepends
        ./home-manager.nix
      ]
      ++ modules;
      systemArgs = {
        modules = modsExtended;
        specialArgs = config.flakeSpecialArgs;
        inherit system;
      };
    in
    nixpkgs.lib.nixosSystem systemArgs
    // {
      # expose module cleanly
      _banananetwork_systemArgs = systemArgs;
    };
  importSystem = path: nixosSystem (importWithFlake path);
in
{
  _class = "flake";
  flake.nixosConfigurations = {

    "x13yz" = importSystem ./de.6nw/pc/x13yz;

    "nyxlite.pc.6nw.de" = importSystem ./de.6nw/pc/nyxlite;

    "emu0.pc.6nw.de" = importSystem ./de.6nw/pc/emu/emu0.nix;
    "emu1.pc.6nw.de" = importSystem ./de.6nw/pc/emu/emu1.nix;
    "emu2.pc.6nw.de" = importSystem ./de.6nw/pc/emu/emu2.nix;

    "dvorak.srv.6nw.de" = importSystem ./de.6nw/srv/dvorak;

    # for VM infra

    "router.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/router;

    "nixnas.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/nixnas;
    "dns.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/dns;

    "immich.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/immich;
    "paperless.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/paperless;

    "nix-builder.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/nix-builder;

    "empty" = importSystem ./de.6nw/temp/empty;

    # (note) build: .#nixosConfigurations.mgmt-iso.config.system.build.isoImage
    "mgmt-iso" = importSystem ./de.6nw/temp/mgmt-iso;

    "iehsrv994" = importSystem ./edu.kit.ieh/iehsrv994;
    "iehsrv995" = importSystem ./edu.kit.ieh/iehsrv995;

    /*
      nixosInstPlasma = nixpkgs.lib.nixosSystem {
        modules = lib.singleton (
          { modulesPath, ... }:
          {
            imports = lib.singleton "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix";
            config.isoImage.squashfsCompression = "zstd";
          }
        );
        system = "x86_64-linux";
      };

      nixosInstMinimal = nixpkgs.lib.nixosSystem {
        modules = lib.singleton (
          { modulesPath, ... }:
          {
            imports = lib.singleton "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix";
          }
        );
        system = "x86_64-linux";
      };
    */

  };
}
