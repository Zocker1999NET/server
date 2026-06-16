{
  config,
  lib,
  pkgs,
  ...
}:
let
  bindCfg = config.services.bind;
  inherit (builtins)
    attrValues
    concatStringsSep
    filter
    mapAttrs
    ;
  inherit (lib) types;
  inherit (lib.lists) optional;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) literalExpression mkOption;
  inherit (lib.strings) escapeShellArg;
  inherit (lib.trivial) flip pipe;
  dynamicDirDefaultName = "bind";
  dynamicDirDefault = "/var/lib/${dynamicDirDefaultName}";
  dynamicDirIsDefault = bindCfg.dynamicDataPath == dynamicDirDefault;
  extZonesMod =
    { config, name, ... }:
    {
      options = {
        dynamicDataPath = mkOption {
          description = ''
            Directory where dynamic zone data should be stored.

            Directory will be created automatically, if it does not exist.
            It should be accessible for the bind user.
          '';
          type = types.str;
          default = "${bindCfg.dynamicDataPath}/${name}";
          defaultText = literalExpression ''
            ''${config.services.bind.dynamicDataPath}/''${config.name}
          '';
        };
        dynamic = mkOption {
          description = ''
            Declares if this zone should support dynamic updates.

            You may want to just define {option}`.update-policy`,
            as then this will be enabled automatically.

            This will set {option}`.file` to a location in {option}`.dynamicDataPath`
            so bind can write to the zone file.
            Dynamic also implies {option}`.master`.
            For defining the initial content of that file,
            please define {option}`.initialContent`.
          '';
          type = types.bool;
          default = false;
          example = true;
        };
        initialContent = mkOption {
          description = ''
            Defines the initial content of the zone file. Only relevant when {option}`.dynamic` is enabled.

            This is only relevant on the first start of bind.
            Afterwards you must use dynamic updates to manage your zone data,
            as changes to this option are no longer applied.
          '';
          type = types.lines;
          example = ''
            $ORIGIN example.com
            $TTL 3600
            @ SOA ns1 hostmaster (
              1  ; serial
              86400  ; refresh
              7200  ; retry
              3600000  ; expire
              3600  ; negative
            )
            ns1 A 192.0.2.91
            ns1 AAAA 2001:db8::91
          '';
        };
        initialFile = mkOption {
          internal = true; # users are expected to use initialContent, for now
          description = "export of initialContent as file";
          default = pkgs.writeText "bind_initial-zone_${name}.db" config.initialContent;
        };
        update-policy = mkOption {
          description = ''
            Defines who is allowed to make dynamic updates in this zone.

            If this is non-empty, {option}`.dynamic` will be enabled automatically.

            ::: {.note}
            Bind can automatically generate a TSIG key,
            which is used for {command}`nsupdate -l`,
            called `local-ddns` (or the name from `options session-keyname`).
            You may want to grant some permissions to that key.
            :::
          '';
          type = types.listOf types.str;
          default = [ ];
          example = [
            "grant \"local-ddns\" zonesub any"
            "grant * selfsub ."
          ];
        };
        # output to upstream module
        additionalConfig = mkOption {
          description = "integrated into `.extraConfig` of zone";
          type = types.lines;
          default = "";
        };
      };
      config = mkMerge [
        # auto detections
        { dynamic = mkIf (config.update-policy != [ ]) true; }
        # for special cases
        (mkIf config.dynamic {
          additionalConfig = mkIf (config.update-policy != [ ]) ''
            update-policy {
              ${concatStringsSep "\n" (map (x: "${x};") config.update-policy)}
            };
          '';
        })
      ];
    };
in
{

  _class = "nixos";

  options.services.bind = {
    dynamicDataPath = mkOption {
      description = ''
        Directory where dynamic data for bind should be stored.

        If the default is selected,
        it will be automaticall created & managed by systemd as `StateDirectory=`,
        otherwise you need to create this yourself
        & make sure it is accessible by bind.
      '';
      readOnly = true;
      type = types.str;
      default = dynamicDirDefault;
    };
    zonesExt = mkOption {
      description = "extension to {option}`services.bind.zones`, because coercedTo type is not mergable";
      type = types.attrsOf (types.submodule extZonesMod);
      default = { };
    };
  };

  config = mkIf bindCfg.enable {
    services.bind = {
      zones = flip mapAttrs bindCfg.zonesExt (
        _: ext:
        mkMerge [
          (mkIf ext.dynamic {
            master = true;
            file = "${ext.dynamicDataPath}/zone.db";
          })
          { extraConfig = ext.additionalConfig; }
        ]
      );
    };
    systemd.services.bind = {
      preStart = ''
        set -x

        # setup per-zone directories for mutable state
        ${pipe bindCfg.zones [
          (mapAttrs (n: x: x // bindCfg.zonesExt.${n} or { }))
          attrValues
          (filter (x: x.dynamic))
          (map (
            x:
            let
              dir = escapeShellArg x.dynamicDataPath;
              zoneDb = escapeShellArg x.file;
            in
            ''
              ${pkgs.coreutils}/bin/mkdir -m 0755 -p ${dir}
              if [[ ! -e ${zoneDb} ]]; then
                echo "initialize dynamic zone at ${zoneDb}"
                cp ${escapeShellArg x.initialFile} ${zoneDb}
              fi
            ''
          ))
          (concatStringsSep "\n")
        ]}
      '';
      serviceConfig = {
        ReadWritePaths = optional (!dynamicDirIsDefault) bindCfg.dynamicDataPath;
        StateDirectory = mkIf dynamicDirIsDefault dynamicDirDefaultName;
      };
    };
  };

}
