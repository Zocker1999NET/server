{
  description = "banananet.work Server & Deployment Controller environment";

  inputs = {

    # packages repositories
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs_unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # required submodules
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    secrix = {
      # TODO revert after my pulls are merged: https://github.com/Platonic-Systems/secrix/pulls/Zocker1999NET
      #url = "github:Platonic-Systems/secrix";
      url = "github:Zocker1999NET/secrix/release-bnet";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # required for configs
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    unattended-installer = {
      url = "github:chrillefkr/nixos-unattended-installer";
      inputs.disko.follows = "disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # TODO experiment with
    # - https://git.sr.ht/~msalerno/wirenix

  };

  outputs =
    { self, ... }@inputs:
    let
      inherit (self) outputs;
      inherit (outputs) lib;
      # every flake "submodule" gets this passed:
      flakeArg = {
        # Usage in submodule:
        # { ... }@flakeArg: { }
        # add "..." this so new ones can easily be added
        inherit
          # tools / shortcuts
          lib # nixpkgs & my lib combined
          # flake refs
          inputs # evaluated inputs
          outputs # evaluated outputs
          ;
        # self: the module’s result, via self-reflection
      };
      importFlakeMod = path: outputs.libAnchors.reflect (import path) flakeArg;
      importFlakeModWithSystem = path: lib.forAllSystems (importFlakeMod path);
    in
    {

      apps = importFlakeModWithSystem ./nix/apps;

      devShells = importFlakeModWithSystem ./nix/devShells;

      homeManagerModules = {
        # combination of all my custom modules
        # these should not change anything until you enable their custom options
        default.imports = [ ./nix/hmModules ];
      };

      lib = outputs.libAnchors // importFlakeMod ./nix/lib;

      # anchors required for importing modules
      libAnchors =
        let
          lib = inputs.nixpkgs.lib;
          inherit (lib.asserts) assertMsg;
        in
        {
          # ({?} -> ?) -> {?} -> ?
          # gives a function access to its own return value
          # by adding it to its first argument (assuming that’s an attrset)
          reflect =
            fun: attrs:
            # TODO is there a more official way?
            assert assertMsg (builtins.isAttrs attrs) ''
              expected a set, got an ${builtins.typeOf attrs}
            '';
            assert assertMsg (!attrs ? "self") ''
              reflect argument already contains a self attribute
            '';
            let
              outputs = fun (attrs // { self = result; });
              result = outputs;
            in
            result;
        };

      nixosConfigurations =
        let
          nixpkgs = inputs.nixpkgs;
          nixosSystem =
            { modules, system }:
            let
              modsExtended = [
                outputs.nixosModules.myOptions
                outputs.nixosModules.withDepends
                { home-manager.sharedModules = [ outputs.homeManagerModules.default ]; }
              ] ++ modules;
            in
            nixpkgs.lib.nixosSystem {
              modules = modsExtended;
              specialArgs = {
                flake = flakeArg;
              };
              inherit system;
            };
        in
        {

          "x13yz" = nixosSystem {
            modules = [
              {
                # TODO check if required & hide into modules
                boot = {
                  initrd = {
                    availableKernelModules = [
                      "nvme" # nvme (probably required for booting)
                      "rtsx_pci_sdmmc" # probably for SD card (required for booting?)
                      "xhci_pci" # for USB 3.0 (required for booting?)
                    ];
                    kernelModules = [
                      "dm-snapshot" # pseudo-required for LVM
                    ];
                  };
                  kernelModules = [
                    "kvm-intel" # do not know if that is required here?
                  ];
                };
              }
              inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x13-yoga
              {
                # hardware
                hardware.cpu.type = "intel";
                hardware.graphics.intel.enable = true;
                programs.captive-browser.interface = "wlp0s20f3";
              }
              {
                # as currently installed
                boot.initrd.luks.devices."luks-herske.lvm.6nw.de" = {
                  device = "/dev/disk/by-uuid/16b8f83d-0450-4c4d-9964-788575a31eec";
                  preLVM = true;
                  allowDiscards = true;
                };
                fileSystems."/" = {
                  device = "/dev/disk/by-uuid/c93557db-e7c5-46ef-9cd8-87eb7c5753dc";
                  fsType = "ext4";
                  options = [
                    "relatime"
                    "discard"
                  ];
                };
                fileSystems."/boot" = {
                  device = "/dev/disk/by-uuid/5F9A-9A2D";
                  fsType = "vfat";
                  options = [
                    "uid=0"
                    "gid=0"
                    "fmask=0077"
                    "dmask=0077"
                  ];
                };
                swapDevices = [ { device = "/dev/disk/by-uuid/8482463b-ceb3-40b3-abef-b49df2de88e5"; } ];
                system.stateVersion = "24.05";
                x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG71dtqG/c0AiFBN9OxoLD35TDQm3m8LXj/BQw60PE0h root@x13yz.pc.6nw.de 2024-07-01";
              }
              {
                # host configuration
                networking.domain = "pc.6nw.de";
                networking.hostName = "x13yz";
                services.fprintd.enable = true;
                x-banananetwork.frontend.convertable = true;
                x-banananetwork.frontend.enable = true;
              }
            ];
            system = "x86_64-linux";
          };

        };

      nixosModules = importFlakeMod ./nix/nixos-modules;

      packages = importFlakeModWithSystem ./nix/packages;

    };
}
