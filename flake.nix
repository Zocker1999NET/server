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
      flakeArg = {
        inherit self inputs outputs;
      };
      # constants
      system = "x86_64-linux";
      # package repositories
      pkgs = import inputs.nixpkgs { inherit system; };
      pkgs_unstable = import inputs.nixpkgs_unstable { inherit system; };
    in
    {

      # shortcut to fully configured secrix
      apps.x86_64-linux.secrix = inputs.secrix.secrix self;

      nixosConfigurations =
        let
          nixosSystem =
            { modules, system }:
            inputs.nixpkgs.lib.nixosSystem {
              modules = [
                outputs.nixosModules.myOptions
                outputs.nixosModules.withDepends
              ] ++ modules;
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
                      "nvme"
                      "rtsx_pci_sdmmc"
                      "xhci_pci"
                    ];
                    kernelModules = [ "dm-snapshot" ];
                  };
                  kernelModules = [ "kvm-intel" ];
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

      nixosModules = {

        # this one includes all of my modules
        # - most of them only change things when enabled (e.g. x-banananetwork.*.enable)
        # - others only introduce small, reasonable changes if other module’s options are set, as reasonable defaults (if I intend to upstream them)
        # however, use on your own discretion
        banananetwork = import ./nix/nixos-modules;

        # this one defines common options for my systems to my modules
        # you definitely do not want to use this
        myOptions = import ./nix/myOptions.nix;

        # this one also includes required dependencies from flake inputs
        withDepends =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          {
            imports = [
              inputs.disko.nixosModules.disko
              inputs.home-manager.nixosModules.home-manager
              inputs.impermanence.nixosModules.impermanence
              inputs.secrix.nixosModules.secrix
              outputs.nixosModules.banananetwork
            ];
            config = {
              nixpkgs.overlays = [
                # TODO until 24.11
                (lib.mkIf (!lib.versionAtLeast lib.version "24.11") (
                  final: prev: { inherit (pkgs_unstable) nixfmt-rfc-style wcurl; }
                ))
              ];
            };
          };

      };

      packages."${system}".secrix-wrapper = pkgs.writeShellApplication {
        name = "secr";
        text = ''
          secrix() {
            set -x
            exec ${outputs.apps.${system}.secrix.program} "$@"
          }

          help() {
            echo "Usages:"
            echo "  $0 [create|rekey|edit|encrypt] <system> [<args> …] <file>"
            echo "  $0 decrypt [<args> …] <file>"
          }

          main() {
            if [[ $# -lt 1 ]]; then
              help
              exit 0
            fi
            cmd="$1"
            shift 1
            case "$cmd" in
              help|-h|--help)
                help
                ;;
              create)
                secrix "$cmd" --all-users --system "$@"
                ;;
              rekey|edit)
                secrix "$cmd" --identity "$SECRIX_ID" --all-users --system "$@"
                ;;
              encrypt)
                secrix "$cmd" --all-users --system "$@"
                ;;
              decrypt)
                secrix "$cmd" --identity "$SECRIX_ID" "$@"
                ;;
            esac
          }

          main "$@"
        '';
      };

      devShells."${system}".default =
        let
          pkgs = pkgs_unstable;
        in
        pkgs.mkShell {
          packages = with pkgs; [
            curl
            rsync
            opentofu
            terranix
            # tooling for services
            outputs.packages.${system}.secrix-wrapper
            wireguard-tools
          ];
          shellHook = ''
            export SECRIX_ID=~/".ssh/id_ed25519"
          '';
        };

    };
}
