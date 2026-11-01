{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.cage.webbrowser;
  restrictions = !cfg.debugMode;

  inherit (lib) types;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.strings) optionalString;
in
{

  _class = "nixos";

  options.services.cage.webbrowser = {

    debugMode = mkEnableOption "debug mode which disables some restrictions for webbrowser, making it easier to debug issues";

    enableDRM = mkEnableOption "DRM support for webbrowser";

    rememberCookies = mkEnableOption "remember cookies & login sessions for webbrowser (also remember cache for performance)";

    url = mkOption {
      description = ''
        URL to open in a web browser within cage.

        Setting this option to a non-null value enables the webbrowser functionality
        by adding a command to {option}`services.cage.commands`.
      '';
      type = with types; nullOr str;
      default = null;
      example = "https://example.com";
    };

  };

  config = mkIf (cfg.url != null) {

    programs.firefox = {
      enable = true;
      addonDefaults = {
        installation_mode = "blocked";
      };
      addonListedDefaults = {
        default_area = "navbar";
        installation_mode = "force_installed";
      };
      addons = {
        "uBlock0@raymondhill.net" = { };
      };
      # TODO optionally block password manager
      policies = {
        AIControls = {
          Default = {
            Value = "blocked";
            Locked = true;
          };
        };
        AutofillAddressEnabled = false;
        AutofillCreditCardEnabled = false;
        BlockAboutAddons = restrictions;
        BlockAboutConfig = restrictions;
        BlockAboutProfiles = restrictions;
        BlockAboutSupport = restrictions;
        BrowserDataBackup = {
          AllowBackup = false;
          AllowRestore = false;
        };
        CaptivePortal = false;
        Cookies = {
          Behavior = "reject-tracker-and-partition-foreign";
          BehaviorPrivateBrowsing = "reject-tracker-and-partition-foreign";
          Locked = true;
        };
        DisableDeveloperTools = restrictions;
        DisableFeedbackCommands = restrictions;
        DisableFirefoxAccounts = true;
        DisableFirefoxScreenshots = restrictions;
        DisableFirefoxStudies = true;
        DisableFormHistory = true;
        DisablePocket = true;
        DisableProfileImport = true;
        DisableSecurityBypass = {
          InvalidCertificate = restrictions;
          SafeBrowsing = true;
        };
        DisableSetDesktopBackground = true;
        DisableTelemetry = true;
        DisplayBookmarksToolbar = "never";
        DontCheckDefaultBrowser = true;
        EnableTrackingProjection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
          EmailTracking = true;
          SuspectedFingerprinting = true;
        };
        EncryptedMediaExtensions = mkIf cfg.enableDRM {
          Enabled = true;
          Locked = true;
        };
        FirefoxHome = {
          Search = false;
          TopSites = false;
          SponsoredTopSites = false;
          Highlights = false;
          Pocket = false;
          Stories = false;
          SponsoredPocket = false;
          SponsoredStories = false;
          Snippets = false;
          Locked = true;
        };
        GenerativeAI = {
          Enabled = false;
          Locked = true;
        };
        HardwareAcceleration = true;
        Homepage = {
          Locked = true;
          StartPage = "none";
        };
        HttpsOnlyMode = "force_enabled";
        InstallAddonsPermission.Default = false;
        IPProtectionAvailable = false;
        NetworkPrediction = false;
        NewTabPage = false;
        NoDefaultBookmarks = true;
        PictureInPicture = {
          Enabled = false;
          Locked = true;
        };
        PopupBlocking = {
          Default = true;
          Locked = true;
        };
        PostQuantumKeyAgreementEnabled = true;
        PrintingEnabled = false;
        SanitizeOnShutdown = {
          Cache = !cfg.rememberCookies;
          Cookies = !cfg.rememberCookies;
          Downloads = true;
          FormData = true;
          History = true;
          Sessions = !cfg.rememberCookies;
          SiteSettings = true;
          Locked = true;
        };
        SkipTermsOfUse = true;
        TranslateEnabled = false;
        UserMessaging = {
          ExtensionRecommendations = false;
          FeatureRecommendations = false;
          UrlbarInterventions = false;
          SkipOnboarding = true;
          MoreFromMozilla = false;
          FirefoxLabs = false;
          Locked = true;
        };
      };
      preferences = {
        # source: https://support.mozilla.org/en-US/questions/1182594
        "browser.sessionstore.max_resumed_crashes" = 0;
        "browser.sessionstore.restore_on_demand" = false;
        "browser.sessionstore.resume_from_crash" = false;
      };
    };

    services.cage = {

      commands = "${getExe pkgs.firefox} ${optionalString restrictions "--kiosk"} ${cfg.url}";

    };

  };

}
