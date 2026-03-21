# applies to all of my machines
# examples: PCs, laptops, VMs, hypervisors, ...

{
  config,
  flake,
  lib,
  options,
  pkgs,
  ...
}:
let
  inherit (builtins) readFile;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.modules) mkIf;
  inherit (lib.trivial) flip;
  thisFlake = {
    # ===SYNC:general/meta/repo/url
    exact = false;
    to = {
      type = "github";
      owner = "Zocker1999NET";
      repo = "server";
      rev = mkIf (flake ? rev) flake.rev;
    };
  };
in
{

  config = {

    assertions = [
      (
        let
          defName = options.networking.hostName.default;
        in
        {
          assertion = config.networking.hostName != defName;
          message = "you must define a hostname (different from default: ${defName})";
        }
      )
    ];

    nix = {

      channel.enable = false;

      daemonCPUSchedPolicy = lib.mkDefault "batch";
      daemonIOSchedClass = lib.mkDefault "best-effort";
      daemonIOSchedPriority = lib.mkDefault 7;

      # IDs starting with a number are not allowed
      registry = {
        # I’m not sure which variant I prefer in day to day usage
        "de.6nw" = thisFlake;
        "de-6nw" = thisFlake;
        "de6nw" = thisFlake;
      };

      settings = {
        auto-optimise-store = true;
        # making nix more feasable to use when one of the substituters cannot be reached
        # (e.g. because of issues with VPN connections)
        connect-timeout = 2; # for connecting to substituters
        experimental-features = [
          "flakes"
          "nix-command"
        ];
        hashed-mirrors = [ "https://tarballs.nixos.org/" ];
        substituters =
          # only configure substituters when not being themself (allowing nix store repairs)
          let
            cfgName = config.networking.fqdnOrHostName;
            subs = {
              "nix-builder.boreth.pve.6nw.de" = "http://[fde3:b424:b5ce:1:be24:11ff:feb5:580c]:5000";
            };
          in
          flip mapAttrsToList subs (name: url: mkIf (cfgName != name) url);
        trusted-public-keys = [
          (readFile ./../nixos/de.6nw/pve.boreth/nix-builder/publicKeyFile)
        ];
        trusted-users = [
          "root"
          "@wheel"
        ];
      };

    };
    systemd.services.nix-daemon.serviceConfig = {
      OOMScoreAdjust = lib.mkDefault 250;
    };

    programs = {

      # for nixos-rebuild with flakes
      git.enable = true;

      ssh = {
        extraConfig = ''
          Host *
            VerifyHostKeyDNS yes
        '';
        hostKeyAlgorithms = [
          "ssh-ed25519"
          "ssh-rsa"
        ];
        # well-known public keys
        knownHosts = {
          "git.banananet.work".publicKey =
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE854AkY/LYJ8kMe1olR+OsAxKIgvZ/JK+G+e0mMVWdH";
          "git.sr.ht".publicKey =
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMZvRd4EtM7R+IHVMWmDkVU3VLQTSwQDSAvW0t2Tkj60";
          "github.com".publicKey =
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
          "gitlab.com".publicKey =
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf";
          "gitlab.kit.edu".publicKey =
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOriuxsWoXA8CnvHndcG9c5u2lBXoCAmeFUhrMEMwY9+";
        };
      };

    };

    security = {

      pki = {
        # in general, these are not blacklisted because those are problematic
        # its more about reducing attack vectors where it is possible
        # and I (most probably) do not rely on services using these CAs
        caCertificateBlacklist = lib.mkDefault [
          # Agence Nationale de Certification Electronique (TN)
          "TunTrust Root CA"
          # BEJING CERTIFICATE AUTHORITY (CN)
          "BJCA Global Root CA1"
          "BJCA Global Root CA2"
          # China Financial Certification Authority (CN)
          "CFCA EV ROOT"
          # Chunghwa Telecom Co., Ltd. (TW)
          "HiPKI Root CA - G1"
          "ePKI Root Certification Authority"
          # GUANG DONG CERTIFICATE AUTHORITY CO.,LTD. (CN)
          "GDCA TrustAUTH R5 ROOT"
          # Hongkong Post (HK)
          "Hongkong Post Root CA 3"
          # iTrusChina Co.,Ltd. (CN)
          "vTrus ECC Root CA"
          "vTrus Root CA"
          # TAIWAN-CA (TW)
          "TWCA Root Certification Authority"
          "TWCA Global Root CA"
          # TrustAsia Technologies, Inc.
          "TrustAsia Global Root CA G3"
          "TrustAsia Global Root CA G4"
          # Turkiye Bilimsel ve Teknolojik Arastirma Kurumu - TUBITAK (TR)
          "TUBITAK Kamu SM SSL Kok Sertifikasi - Surum 1"
          # UniTrust (CN)
          "UCA Global G2 Root"
          "UCA Extended Validation Root"
        ];
      };

    };

    services = {

      fail2ban = {
        enable = mkIf config.services.openssh.enable true;
        ignoreIP = mkIf config.services.tailscale.enable [
          "100.64.0.0/10"
          "fd7a:115c:a1e0::/96"
        ];
        bantime = "5m";
        bantime-increment = {
          enable = true;
          maxtime = "48h";
          overalljails = true;
        };
      };

      smartd = {
        # so smartd reports them by their /dev/disk/by-id name (https://www.smartmontools.org/ticket/1390#comment:2)
        defaults.autodetected = "-d by-id";
      };

      # TODO upstream with better option for rules
      # required because smartd only detects drives when launching
      # so the udev rule makes smartd useable with removeable drives
      # "restart-or-reload" is required because smartd fails to start if no SMART drive was found
      udev.extraRules = mkIf config.services.smartd.enable ''
        ACTION=="add|change|move|remove", SUBSYSTEM=="scsi_disk", RUN+="${config.systemd.package}/bin/systemctl --no-block try-reload-or-restart smartd.service"
      '';

    };

    # TODO upstream
    system.activationScripts.diff = {
      supportsDryActivation = true;
      text = ''
        if [[ -e /run/current-system ]]; then
          echo "--- diff to current-system"
          ${lib.getExe pkgs.nvd} --nix-bin-dir=${config.nix.package}/bin diff /run/current-system "$systemConfig"
          echo "---"
        fi
      '';
    };

    # ensure activation scripts are fine
    # TODO replace with proper check as seen in https://github.com/NixOS/nixpkgs/pull/149932
    # (because of this: added shellcheck as "offline-installation dependencies")
    system.activatableSystemBuilderCommands = lib.mkAfter ''
      ${lib.getExe pkgs.shellcheck} --check-sourced --external-sources --norc --severity=warning $out/activate $out/dry-activate
    '';

    time = {
      timeZone = lib.mkDefault "Etc/UTC";
    };

    x-banananetwork = {
      improvedDefaults.enable = true;
      secrix = {
        enable = true;
        hostKeyType = "ed25519";
      };
    };

  };

}
