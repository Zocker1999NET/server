{ config, lib, ... }:
let
  inherit (builtins) concatStringsSep;
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkMerge;

  # derived constants
  inherit (config.networking) hostName;

  # constants
  guestAccount = "nobody";
  smbGroup = "smb";
  smbPort = 445;
in
{
  _class = "nixos";
  config = mkMerge [

    # minimal default for sharing with Linux clients
    # with appropriate network security
    {
      services.samba = {
        enable = true;
        # those two are not required for simple scenarios with Linux clients
        nmbd.enable = false;
        winbindd.enable = false;
        settings.global = {
          workgroup = "WORKGROUP";
          "server string" = hostName;
          "netbios name" = hostName;
          security = "user"; # require authentication against Unix user database
          "server min protocol" = "SMB3";
          #"server smb encrypt" = "desired"; # even "desired" not supported by some Linux implementations
          # disable default shenanigangs because Samba is optimized for Linux-Windows sharing
          "map archive" = "no"; # https://stackoverflow.com/a/20966148
          "nt acl support" = "no";
        };
      };
    }

    # configure default share access control:
    # - restrict to explicitly allowed users (either per share or as part of group smb)
    # - configure guest access to be read only & secure as good as possible by default
    # (including comments on what to override per share, if desired)
    {
      services.samba.settings.global = {
        "guest account" = guestAccount;
        # override this to true to allow guests
        "guest ok" = "no";
        # invalid user names -> guest account (required for guest shares to work in the first place)
        "map to guest" = "bad user";
        # override this to "" to allow guests to write as well
        "read list" = concatStringsSep " " [
          guestAccount # by default guests may only read
        ];
        # override this to further restrict or expand to explicitly called users
        "valid users" = concatStringsSep " " [
          guestAccount # so list is always non-empty -> effective
          "+${smbGroup}" # permit users in smbGroup by default
        ];
      };
      # create group
      users.groups.${smbGroup} = { };
    }

    # open firewall, but only what we need
    {
      networking.firewall = {
        # we only need SMB port itself
        # TODO allow UDP port when samba supports SMB over QUIC
        allowedTCPPorts = singleton smbPort;
      };
      services.samba = {
        openFirewall = false; # opens more than required
      };
    }

    # configure useful logging
    {
      services.samba.settings.global = {
        # log everything to systemd
        "logging" = "systemd";
        "log level" = concatStringsSep " " [
          "auth_audit:2" # log Authentication Failures
        ];
      };
    }

  ];
}
