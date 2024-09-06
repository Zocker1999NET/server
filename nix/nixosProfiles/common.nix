# applies to all of my machines
# examples: PCs, laptops, VMs, hypervisors, ...

{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.x-banananetwork.allCommon;
in
{

  options = {

    x-banananetwork.allCommon = {

      # TODO remove option, plan:
      # - verify all configs still build (nix flake check)
      #   - i.e. all with allCommon.enable=true are using this module
      # - remove option here & from all configs
      # - again: nix flake check
      enable = lib.mkEnableOption "for compatibility reasons" // {
        default = true;
        internal = true;
      };

    };

  };

  config = {

    assertions = [
      {
        assertion = cfg.enable;
        message = "config imported profiles/common but tried to disable it";
      }
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

      settings = {
        auto-optimise-store = true;
        experimental-features = [
          "flakes"
          "nix-command"
        ];
        hashed-mirrors = [ "https://tarballs.nixos.org/" ];
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
          "git.banananet.work".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE854AkY/LYJ8kMe1olR+OsAxKIgvZ/JK+G+e0mMVWdH";
          "git.sr.ht".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMZvRd4EtM7R+IHVMWmDkVU3VLQTSwQDSAvW0t2Tkj60";
          "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
          "gitlab.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf";
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
          # UniTrust (CA)
          "UCA Global G2 Root"
          "UCA Extended Validation Root"
        ];
      };

    };

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
    # TODO upstream, probably replacing https://github.com/NixOS/nixpkgs/pull/149932
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
