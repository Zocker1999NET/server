{
  inputs,
  lib,
  self,
  ...
}:
let
  inherit (builtins) mapAttrs;
  inherit (lib.trivial) flip;

  # overwrite nixosConfigurations
  modifiedConfigs = flip mapAttrs self.nixosConfigurations (
    _: cfg:
    cfg.extendModules {
      modules = [
        self.modules.nixos.flakeSuppressRevision # avoid rebuilds after unrelated changes
      ];
    }
  );
  modifiedSelf = self // {
    nixosConfigurations = modifiedConfigs;
    outputs = self.outputs // {
      nixosConfigurations = modifiedConfigs;
    };
  };
in
{
  _class = "flake";
  perSystem =
    { pkgs, ... }:
    {
      checks = {

        # similar to disko-install-menu.checks.SYSTEM.offineBuilds-*
        # (TODO in disko-install-menu, export test framework & use here)
        # TODO still rebuilds on unsignificant changes, fix that
        diskoOfflineInstall = pkgs.testers.runNixOSTest {
          name = "diskoOfflineInstall";
          # similar as above: allow customizations with overlays
          node.pkgsReadOnly = false;
          nodes.node.imports = [
            inputs.disko-install-menu.nixosModules.default
            {
              programs.disko-install-menu = {
                enable = true;
                offlineCapable = true;
                options = {
                  # should not be used on --debug-test-build
                  # & fixed to avoid rebuilds after unrelated changes
                  defaultFlake = "/non-existing/path_to/flake";
                  defaultHost = "empty";
                };
                listedFlakes.defaultFlake = {
                  offlineHosts.empty = true;
                  offlineReference = modifiedSelf;
                };
              };
              virtualisation = {
                memorySize = 4 * 1024;
                useNixStoreImage = true; # verify that installer can run with all detected dependencies (see https://github.com/NixOS/nix/issues/14207)
                writableStore = true;
              };
            }
            # make offlineCapable tests fail more likely when installer config is designed more minimalistically
            {
              xdg.mime.enable = false;
            }
            ./../../offlineInstallDeps.nix
          ];
          testScript = ''
            node.start()
            node.wait_for_unit("default.target")

            # ensure offline
            node.block()
            node.execute("ip -4 route del default")
            node.execute("ip -6 route del default")
            node.fail("ping -c 2 9.9.9.9")
            node.fail("ping -c 2 2620:fe::fe")

            # execute build
            node.succeed("disko-install-menu --debug-test-build")
          '';
        };

      };
    };
}
