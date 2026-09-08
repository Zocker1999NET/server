{
  config,
  lib,
  ...
}:
let
  inherit (builtins) concatLists;
  inherit (lib.options) mkOption;
  inherit (lib.strings) concatStringsSep;
  inherit (lib.types) listOf str;
in
{

  _class = "nixos";

  imports = [
    # a remote builder should also be able to build for foreign architectures
    ./nixCrossArchEmulation.nix
  ];

  options.nix = {
    supportedBuildSystems = mkOption {
      description = ''
        All systems this builder can build for:
        its own native system plus the emulated ones.
      '';
      type = listOf str;
      internal = true;
      readOnly = true;
      default = [
        config.nixpkgs.localSystem.system
      ]
      ++ config.boot.binfmt.emulatedSystems;
    };
    supportedBuildSystemsConcat = mkOption {
      description = ''
        `nix.supportedBuildSystems` as a comma-separated string,
        as expected by the `--builders` option of `nix build`.
      '';
      type = str;
      internal = true;
      readOnly = true;
      default = concatStringsSep "," config.nix.supportedBuildSystems;
    };
  };

  config = {

    nix.sshServe = {
      # provides remote builder with user nix-ssh
      enable = true;
      keys = concatLists [
        config.x-banananetwork.sshPublicKeys
        # allow connection for remote building
        [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKko0tcHOmCxi/ilFbVJ9N+U+34B9r6RFdmGfrBaob6C root@x13yz.pc.6nw.de"
        ]
      ];
      protocol = "ssh-ng";
      trusted = true;
      write = true;
    };

  };
}
