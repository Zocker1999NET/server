{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkDefault mkForce;
in
{
  _class = "nixos";
  imports = [

    # personal test expectations
    {
      # required for test driver to send correct chars to TTY
      console.keyMap = mkForce "us";
      # packages for testing
      environment.systemPackages = with pkgs; [
        curl
        dig
        jq
      ];
      # prefer networkd
      networking.useNetworkd = mkDefault true;
    }

    # speeds up builds & prevents assertions to break
    {
      boot.loader.grub.enable = mkForce false;
      boot.loader.systemd-boot.enable = mkForce false;
    }

    # disable test network magic
    {
      networking = {
        extraHosts = mkForce "";
      };
    }

    # prevent interactive test nodes having Internet
    (
      # by disabling test driver backdoor interface in an hacky way
      # esp. this is required to have no Internet in interactive tests
      let
        backdoorInterface = "eth0";
      in
      {
        # in case normal networking is used
        networking.interfaces = mkForce { };
        # in case systemd-networkd is used
        systemd.network = {
          networks."20-backdoor" = {
            matchConfig.Name = backdoorInterface;
            linkConfig.Unmanaged = true;
          };
          wait-online.ignoredInterfaces = singleton backdoorInterface;
        };
      }
    )

  ];
}
