# applies to all of my machines
# examples: PCs, laptops, VMs, hypervisors, ...

{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.x-banananetwork.allCommon;
in
{


  options = {

    x-banananetwork.allCommon = {

      enable = lib.mkEnableOption ''
        settings common to all systems
        a set of opionated options to make systems useable & debugable for users.

        This means e.g. adding common, useful tools and add documentation.
      '';

    };

  };


  config = lib.mkIf cfg.enable {


    documentation = {

      man.mandoc.settings.output = {
        paper = lib.mkDefault "a4";
      };

    };


    i18n = {
      # inspired by https://wiki.archlinux.org/title/Locale
      defaultLocale = lib.mkDefault "en_US.UTF-8";
      extraLocaleSettings = {
        LANGUAGE = lib.mkDefault "en_US:en:C:de_DE";
        LC_COLLATE = lib.mkDefault "C"; # language independent sorting
        LC_MEASUREMENT = "de_DE.UTF-8"; # metric
        LC_PAPER = "de_DE.UTF-8"; # metric
        LC_TELEPHONE = "de_DE.UTF-8";
        LC_TIME = lib.mkDefault "en_DK.UTF-8"; # ISO 8601
      };
    };


    nix = {
      channel.enable = false;

      settings = {
        allowed-users = [
          "root"
          "@wheel"
        ];
        auto-optimise-store = true;
        experimental-features = [
          "flakes"
          "nix-command"
        ];
        hashed-mirrors = [
          "https://tarballs.nixos.org/"
        ];
        trusted-users = [
          "root"
        ];
      };
    };
    systemd.services.nix-daemon.serviceConfig = {
      CPUSchedulingPolicy = "batch";
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
      OOMScoreAdjust = lib.mkDefault 250;
    };


    # well-known public keys
    programs.ssh = {
      hostKeyAlgorithms = [
        "ssh-ed25519"
        "ssh-rsa"
      ];
      knownHosts = {
        "git.banananet.work".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE854AkY/LYJ8kMe1olR+OsAxKIgvZ/JK+G+e0mMVWdH";
        "git.sr.ht".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMZvRd4EtM7R+IHVMWmDkVU3VLQTSwQDSAvW0t2Tkj60";
        "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        "gitlab.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf";
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
          ${pkgs.nvd}/bin/nvd --nix-bin-dir=${config.nix.package}/bin diff /run/current-system "$systemConfig"
          echo "---"
      '';
    };


    time = {
      hardwareClockInLocalTime = lib.mkDefault false;
      timeZone = lib.mkDefault "Etc/UTC";
    };


    x-banananetwork = {

      improvedDefaults.enable = true;

    };


  };


}
