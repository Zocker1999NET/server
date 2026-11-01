{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.firefox;

  inherit (builtins) elem mapAttrs removeAttrs;
  inherit (lib) types;
  inherit (lib.attrsets) filterAttrs mapAttrsToList;
  inherit (lib.lists) flatten;
  inherit (lib.modules) mkDefault mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.strings) escapeNixString;
  inherit (lib.trivial) flip mergeAttrs pipe;

  # custom types
  nullOrEnum = l: with types; nullOr (enum l);
  nullOrMultiEnum = l: with types; nullOr (listOf (enum l));
  addonSettings =
    imports:
    types.submodule {
      freeformType = with types; attrsOf json;
      inherit imports;
    };

  # helper functions
  filterNonNulls = filterAttrs (_: v: v != null);
  filterNonEmpty = filterAttrs (_: v: v != null && v != { });

  # options which Firefox allows for individual & `*` (all) add-ons
  generalAddonsModule = _: {
    options = {

      default_area = mkOption {
        description = ''
          Where the add-on icon is placed by default.

          After installation, this option is ignored.

          This option is available in Firefox 113+.
        '';
        type = nullOrEnum [
          "navbar"
          "menupanel"
        ];
        default = null;
      };

      private_browsing = mkOption {
        description = ''
          Whether to enable this add-on in private browsing windows.

          This option is available in Firefox 136+.
        '';
        type = with types; nullOr bool;
        default = null;
      };

      temporarily_allow_weak_signatures = mkOption {
        description = ''
          Whether to allow installing add-ons signed with deprecated signature algorithms.

          This option is available in Firefox 127+.
        '';
        type = with types; nullOr bool;
        default = null;
      };

      updates_disabled = mkOption {
        description = ''
          Whether to disable automatic updates for this add-on.

          This option is available in Firefox 89+.
        '';
        type = with types; nullOr bool;
        default = null;
      };

    };
  };

  # options which Firefox only allows for `*` (all) add-ons
  allAddonsModule = _: {
    options = {

      allowed_types = mkOption {
        description = ''
          Restricts which types of add-ons can be installed.

          **Note:**
          This setting only applies when installation is otherwise allowed.
          If {option}`installation_mode` is set to `blocked` (either for a specific ID or for `*`),
          extensions remain blocked regardless of {option}`allowed_types`.
        '';
        type = nullOrMultiEnum [
          "dictionary"
          "extension"
          "locale"
          "theme"
          "sitepermission"
        ];
        default = null;
      };

      blocked_install_message = mkOption {
        description = ''
          Message to show when a user attempts to install a blocked add-on.

          This setting allows you to append text to the generic error message displayed when an extension is blocked.
          This could be used to direct users to your help desk,
          explain why a particular extension is blocked,
          or something similar.
        '';
        type = with types; nullOr str;
        default = null;
      };

      install_sources = mkOption {
        description = ''
          A list of sources from which installing extensions is allowed using URL match patterns.
          This is unnecessary if you are only allowing the installation of certain extensions by ID.

          Each item in this list is an extension-style match pattern.
          Users will be able to easily install items from any URL that matches an item in this list.

          Both the location of the .xpi file
          and the page where the download is started (the referrer)
          must be allowed by these patterns.
        '';
        type = with types; nullOr (listOf str);
        default = null;
      };

      installation_mode = mkOption {
        description = ''
          Whether installing add-ons is allowed or blocked.

          This can be overridden for specific add-ons in {option}`programs.firefox.addons`.
        '';
        type = nullOrEnum [
          "blocked"
          "allowed"
        ];
        default = null;
      };

      restricted_domains = mkOption {
        description = ''
          A list of domains on which content scripts,
          those supplied by add-ons, cannot be run.
        '';
        type = with types; nullOr (listOf str);
        default = null;
      };

    };
  };

  # options which Firefox only allows for individual add-ons, not `*` (all) add-ons
  individualAddonsModule = _: {
    options = {

      installation_mode = mkOption {
        description = ''
          Whether the add-on is allowed, blocked, or installed.

          Force-installed add-ons cannot be uninstalled or disabled by the user.
        '';
        type = nullOrEnum [
          "blocked"
          "allowed"
          "normal_installed"
          "force_installed"
        ];
        example = "normal_installed";
      };

    };
  };

  # options only applicable to individual add-ons, not `*` (all) add-ons
  specialAddonsModule = { config, name, ... }: {
    options = {

      # special settings
      # (must be removed by enrichAddons)

      id = mkOption {
        description = "The add-on ID.";
        type = with types; str;
        default = name;
      };

      policies = mkOption {
        description = ''
          The policies applied to this add-on.

          These policies must be explicitly supported by the add-on.
          For more context, see [3rdparty Policy](https://mozilla.github.io/policy-templates/#3rdparty).
        '';
        type = with types; json;
        default = { };
      };

      # special special cases

      # install_url does not really make sense in addonListedDefaults, because it cannot depend on the add-on ID there
      install_url = mkOption {
        description = ''
          URL from which Firefox downloads an add-on for installation and updates.

          This is required for `force_installed`/`normal_installed` add-ons.

          Firefox automatically updates the extension when the XPI file’s internal version changes.
          If the URL is pinned to a specific version, Firefox will not update the extension automatically.

          Use `file:///` URL for local files.
          Firefox will then update the extension whenever the XPI file changes.
        '';
        type = with types; nullOr str;
        default = "https://addons.mozilla.org/firefox/downloads/latest/${config.id}/latest.xpi";
        defaultText = "https://addons.mozilla.org/firefox/downloads/latest/\${config.id}/latest.xpi";
      };

    };
  };
in
{

  _class = "nixos";

  options.programs.firefox = {

    addonDefaults = mkOption {
      description = ''
        Default settings for Firefox add-ons *not* listed
        in {option}`programs.firefox.addons`.

        Do not confuse with {option}`programs.firefox.addonListedDefaults`.
      '';
      type = addonSettings [
        generalAddonsModule
        allAddonsModule
      ];
      default = { };
      example = {
        allowed_types = [ "theme" ];
        installation_mode = "allowed";
      };
    };

    # this is useful for certain special cases, e.g. installation_mode = "force_installed" on all listed add-ons
    addonListedDefaults = mkOption {
      description = ''
        Default settings for Firefox add-ons *listed*
        in {option}`programs.firefox.addons`.

        These are injected into {option}`programs.firefox.addons`
        with {var}`lib.modules.mkDefault`.

        Do not confuse with {option}`programs.firefox.addonDefaults`.
      '';
      type = addonSettings [
        generalAddonsModule
        individualAddonsModule
      ];
      default = { };
      example = {
        installation_mode = "force_installed";
      };
    };

    addons = mkOption {
      description = ''
        Firefox add-ons to install newest versions from the Mozilla Add-ons site.
      '';
      type = types.attrsOf (addonSettings [
        generalAddonsModule
        individualAddonsModule
        specialAddonsModule
        (_: { config = mkDefault cfg.addonListedDefaults; })
      ]);
      default = { };
      example = {
        "uBlock0@raymondhill.net" = {
          default_area = "menupanel";
          installation_mode = "force_installed";
        };
      };
    };

  };

  config = {

    assertions = flatten [

      {
        assertion = !cfg.addons ? "*";
        message = "programs.firefox.addons.\"*\" is not allowed, prefer .addonDefaults instead";
      }

      (flip mapAttrsToList cfg.addons (
        id: c: [
          {
            assertion =
              (elem c.installation_mode [
                "normal_installed"
                "force_installed"
              ])
              -> c.install_url != null;
            message = "programs.firefox.addons.${id}: .install_url must be set when .installation_mode = ${escapeNixString c.installation_mode}";
          }
        ]
      ))

    ];

    warnings = flatten [

      (mkIf (cfg.addonDefaults.installation_mode == "blocked" && cfg.addonDefaults.allowed_types != null)
        "programs.firefox.addonDefaults: .allowed_types is ignored because .installation_mode is set to \"blocked\""
      )
      (mkIf
        (
          cfg.addonListedDefaults.installation_mode == "blocked"
          && cfg.addonListedDefaults.install_sources != null
        )
        "programs.firefox.addonListedDefaults: .install_sources is ignored when .installation_mode is set to \"blocked\""
      )

      (flip mapAttrsToList cfg.addons (
        id: c: [
          (mkIf
            (
              (elem c.installation_mode [
                "blocked"
                "allowed"
              ])
              && c.install_url != null
            )
            "programs.firefox.addons.${id}: .install_url is ignored when .installation_mode = ${escapeNixString c.installation_mode}"
          )
        ]
      ))

    ];

    programs.firefox.policies = filterNonEmpty {
      "3rdparty" = pipe cfg.addons [
        (mapAttrs (_: c: c.policies))
        filterNonEmpty
      ];
      ExtensionSettings = pipe cfg.addons [
        (mapAttrs (
          _:
          flip pipe [
            (flip removeAttrs [
              "id"
              "policies"
            ])
            filterNonNulls
          ]
        ))
        (mergeAttrs {
          "*" = filterNonNulls cfg.addonDefaults;
        })
        filterNonEmpty
      ];
    };

  };

}
