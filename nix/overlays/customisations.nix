{ lib, ... }@flakeArg:
{ pkgs_unstable, ... }@systemArg:
final: prev:
let
  wrapPackage =
    pkg: envs:
    let
      envArgs = lib.trivial.pipe envs [
        (lib.attrsets.mapAttrsToList (
          n: v: [
            n
            v
          ]
        ))
        (map (x: [ "--set" ] ++ x))
        lib.lists.flatten
        lib.strings.escapeShellArgs
      ];
    in
    pkg.overrideAttrs (old: {
      postInstall = ''
        ${old.postInstall or ""}
        wrapProgram $out/bin/${old.meta.mainProgram or old.pname} ${envArgs}
      '';
    });
in
{
  ipv6calc = wrapPackage prev.ipv6calc {
    IPV6CALC_DB_IP2LOCATION_DISABLE = "1";
    IPV6CALC_DB_DBIP2_DISABLE = "1";
  };
}
