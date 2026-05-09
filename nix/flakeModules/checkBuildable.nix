{
  config,
  lib,
  self,
  ...
}:
let
  inherit (builtins)
    attrValues
    concatStringsSep
    filter
    listToAttrs
    mapAttrs
    ;
  inherit (lib) types;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) concatMap toList;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.strings) escapeShellArg;
  inherit (lib.trivial) flip pipe;
  inherit (lib.types) isType;
  cfg = config.checkBuildable;
in
{

  _class = "flake";

  options.checkBuildable = {

    enable = mkOption {
      description = ''
        Whether to add all buildable outputs to the checks output.

        All checks are discarding their outputs,
        so e.g. for example an CI and/or build cache
        can cache a large amount of check outputs.
      '';
      type = types.bool;
      default = true;
      example = false;
    };

  };

  config = mkIf cfg.enable {
    perSystem =
      {
        pkgs,
        self',
        system,
        ...
      }:
      let

        simpleRun =
          name:
          pkgs.runCommandWith {
            inherit name;
            runLocal = true;
            stdenv = pkgs.stdenvNoCC;
          };
        # idea: throw away any result, except the info that the original build succeeded
        testBuildSucceed =
          name: deps:
          simpleRun name ''
            ${pipe deps [
              toList
              (map (x: "echo ${escapeShellArg x}"))
              (concatStringsSep "\n")
            ]}
            touch $out
          '';

        # for wrapping values which should not be evaluated immediately
        # but which are != null
        bubbleWrap = value: {
          _type = "bubbleWrap";
          inherit value;
        };
        bubbleUnwrap =
          wrapped:
          if isType "bubbleWrap" wrapped then wrapped.value else abort "expected value to be bubbleWrap'ed";

        # we wrap most to everything for efficiency reasons during evaluation of which args exist
        plainExporters = {
          nixosConfigurations =
            sysCfg:
            # using custom systemArgs reflection to be more efficient
            if sysCfg._banananetwork_systemArgs.system != system then
              null
            else
              bubbleWrap sysCfg.config.system.build.toplevel;
        };
        systemExporters = {
          apps = app: bubbleWrap app.program;
          devShells = shell: bubbleWrap shell;
          packages = pkg: bubbleWrap pkg;
        };

      in
      {
        checks = pipe null [
          # prepare exporters
          (
            _:
            flip mapAttrs plainExporters (
              out: exp: {
                output = out;
                exporter = exp;
                prefix = [ out ];
                source = self;
              }
            )
            // flip mapAttrs systemExporters (
              out: exp: {
                output = out;
                exporter = exp;
                prefix = [
                  out
                  system
                ];
                source = self';
              }
            )
          )
          attrValues
          # apply exporters
          (concatMap (
            {
              output,
              prefix,
              source,
              exporter,
            }:
            (flip mapAttrsToList (source.${output} or { }) (
              attr: elem: {
                # two layer of escaping, i.e. `checks."configs.\"host.example\""`, isn’t supported by nix CLI
                # so do not use showAttrPath, instead use ":" to avoid having two layers of dots `.`
                # (also avoid "/" as otherwise the attr names cannot be used as file names)
                # (dots are preferred for hostnames in e.g. nixosConfigurations)
                name = concatStringsSep ":" (prefix ++ [ attr ]);
                value = exporter elem;
              }
            ))
          ))
          # filter suppressed values
          (filter ({ value, ... }: value != null))
          # finalize
          listToAttrs
          # unwrap bubbleWrap
          (mapAttrs (_: bubbleUnwrap))
          # suppress build results
          (mapAttrs (name: value: testBuildSucceed "check_${name}" value))
        ];
      };
  };

}
