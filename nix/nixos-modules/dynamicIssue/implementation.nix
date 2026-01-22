{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.services.dynamicIssue;

  inherit (builtins)
    attrNames
    attrValues
    concatStringsSep
    filter
    mapAttrs
    ;
  inherit (lib) types;
  inherit (lib.attrsets) filterAttrs mapAttrs' nameValuePair;
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.strings) escapeShellArg;
  inherit (lib.trivial) flip pipe;

  # constant
  issueDir = "/etc/issue.d";
  commonService = {
    RemainAfterExit = true;
    Type = "oneshot";
  };
  isolateService = commonService // {
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateTmp = "disconnected";
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectSystem = "strict";
    RemoveIPC = true;
    RestrictSUIDSGID = true;
    SystemCallFilter = "@system-service";
    SystemCallErrorNumber = "EPERM";
  };

  descRender = desc: "displaying ${desc} via the greeter for unauthenticated users";

  module = types.submodule (
    { config, name, ... }:
    {
      options = {

        # static values
        enable = mkOption {
          type = types.bool;
          internal = true;
          readOnly = true;
          default = cfg.modules.${name}.enable;
        };
        name = mkOption {
          type = types.str;
          internal = true;
          readOnly = true;
          default = name;
        };
        generator = mkOption {
          type = types.package;
          internal = true;
          readOnly = true;
          default = pkgs.writeShellApplication {
            name = "dynamicIssue-module-${name}-generator";
            text = config.script;
          };
        };
        outFile = mkOption {
          type = types.str;
          internal = true;
          readOnly = true;
          default = "${issueDir}/${name}.issue";
        };

        # options
        description = mkOption {
          type = types.str;
        };
        script = mkOption {
          description = ''
            The script which generates what will be additionally displayed by getty.

            The stdout of the script will be captured & displayed by getty,
            while the stderr will be ignored by getty.
            But both will be logged to the journal.
            If the script errors out, getty will display a short error message instead.

            The script will be built by `pkgs.writeShellApplication`.
          '';
          type = types.str;
          example = ''
            echo "prepare greeting the whole world" >&2
            echo "Hello World!"
            echo "We greeted you at $(date)"
            echo  # extra line at end as spacer
          '';
        };
        inherit (options.systemd.services.type.nestedTypes.elemType.getSubOptions [ ]) after startAt;

      };
    }
  );
in
{

  options.services.dynamicIssue = {

    implementations = mkOption {
      description = ''
        Scripts for generating dynamic content for `${issueDir}`.
        Greeters like getty should display them before asking for the user for credentials.
        Can be used to provide non-sensitive information aiding users or administrators
        (e.g. network status, SSH host public keys, …).

        Be aware that these scripts will usually only be called once per boot
        if their `startAt` option is not configured.
        Further, it is up to the greeter to also reload the newly written data.
      '';
      internal = true; # intended for module authors
      type = types.attrsOf module;
      default = { };
    };

    modules = flip mapAttrs cfg.implementations (
      _: v: {
        enable = mkEnableOption (descRender v.description);
      }
    );

  };

  config = {
    systemd.services = pipe cfg.implementations [
      (filterAttrs (_: val: val.enable))
      (mapAttrs' (
        name: val:
        nameValuePair "dynamicIssue-module-${name}" {
          description = "Generating ${issueDir} file for ${descRender val.description}";
          inherit (val) after startAt;
          # dependencies
          wantedBy = singleton "getty@.service";
          # service config
          restartIfChanged = true;
          serviceConfig = isolateService // {
            ReadWritePaths = singleton val.outFile;
          };
          # script
          enableStrictShellChecks = true;
          script = ''
            gen=${escapeShellArg (getExe val.generator)}
            out_file=${escapeShellArg val.outFile}
            # prepare generator execution
            echo "+ $gen" >&2
            # tee output to logs, in case it contains error message
            if $gen | tee "$out_file"; then
              exit 0;
            else
              exit_code="$?"
              echo $gen "exited with $exit_code" >&2
              # overwrite output file with error statement
              echo "[dynamicIssue ${name} failed, see logs in journal]" > "$out_file"
              # repeat exit code to systemd
              exit "$exit_code"
            fi
          '';
          postStop = "echo '' > ${escapeShellArg val.outFile}";
        }
      ))
      (
        services:
        let
          moduleServiceNames = pipe services [
            attrNames
            (map (name: "${name}.service"))
          ];
          outFileNames = pipe cfg.implementations [
            attrValues
            (filter (x: x.enable))
            (map (x: escapeShellArg x.outFile))
            (concatStringsSep " ")
          ];
        in
        services
        // {
          # required as extra service so further services can be limited to issueDir
          dynamicIssue-create-directory = {
            description = "Create ${issueDir} for further dynamicIssue services";
            requiredBy = moduleServiceNames;
            serviceConfig = commonService;
            enableStrictShellChecks = true;
            script = "mkdir --parents ${escapeShellArg issueDir}";
          };
          # required because of more strict isolation of module services
          dynamicIssue-preparation = {
            description = "Pre-generate all ${issueDir} files";
            after = singleton "dynamicIssue-create-directory.service";
            before = moduleServiceNames;
            requires = singleton "dynamicIssue-create-directory.service";
            requiredBy = moduleServiceNames;
            serviceConfig = isolateService // {
              ReadWritePaths = singleton issueDir;
            };
            enableStrictShellChecks = true;
            script = ''
              touch ${outFileNames}
            '';
          };
        }
      )
    ];
  };

}
