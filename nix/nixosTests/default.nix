{
  inputs,
  lib,
  outputs,
  ...
}@flakeArg:
{ pkgs, ... }@systemArg:
let
  machines = outputs.nixosConfigurations;
  nixosTest =
    {
      # can only accept attrs as nodes configs
      nodes ? { },
      config ? { },
      ...
    }@args:
    let
      extConfig.config = {
        # speeds up builds & prevents assertions to break
        boot.loader.grub.enable = lib.mkForce false;
        boot.loader.systemd-boot.enable = lib.mkForce false;
        # packages for testing
        environment.systemPackages = with pkgs; [
          curl
          dig
          jq
        ];
        # disable all VM test network magic (TODO extract)
        networking = {
          interfaces = lib.mkForce { };
          extraHosts = lib.mkForce "";
          #hostName = lib.mkDefault name;
          useNetworkd = lib.mkDefault true;
        };
        # disable test driver backdoor interface (hacky)
        systemd.network = {
          # esp. this is required to have no Internet in interactive tests
          networks."20-backdoor" = {
            matchConfig.Name = "eth0";
            linkConfig.Unmanaged = true;
          };
          wait-online.ignoredInterfaces = lib.singleton "eth0";
        };
        # avoid warnings because of modified root password
        users.users.root = {
          # TODO which of those is set by the test driver?
          #hashedPassword = lib.modules.mkTestOverride null;
          #hashedPasswordFile = lib.modules.mkTestOverride null;
          #initialPassword = lib.modules.mkTestOverride null;
          #initialHashedPassword = lib.modules.mkTestOverride null;
        };
      };
    in
    pkgs.nixosTest (
      args
      // {
        nodes = lib.flip builtins.mapAttrs nodes (
          name: node: {
            imports = [
              node
              extConfig
            ];
          }
        );
      }
    );
  nixosIntegrationTest =
    tested: # from machines
    {
      name ? "full",
      testScript ? "",
      # can only accept attrs as nodes configs
      nodes ? { },
      config ? { },
      ...
    }@args:
    let
      hostName = tested.config.networking.hostName;
      fqdn = tested.config.networking.fqdn;
    in
    nixosTest (
      {
        name = "${fqdn}_integration-test";
        nodes = nodes // {
          tested = {
            imports = tested._banananetwork_systemArgs.modules;
            config._module.args.flake = flakeArg;
          };
        };
        testScript = ''
          # fix access as that name
          tested = ${builtins.replaceStrings [ "-" ] [ "_" ] hostName}
          # fast bootup
          start_all()
          ${testScript}
        '';
      }
      // (builtins.removeAttrs args [
        "name"
        "nodes"
        "testScript"
        "config"
      ])
    );

in
{

  empty = nixosIntegrationTest machines.empty {
    testScript = ''
      tested.wait_for_unit("default.target")
    '';
  };

}
