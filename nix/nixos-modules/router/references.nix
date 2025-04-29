# declaring & collecting reference tables for cross-interface & cross-device lookups
{
  lib, # uses some of my library extensions
  ...
}@flakeArg:
{ config, ... }:
let
  cfg = config.x-banananetwork.routerVM;
  refCfg = cfg.references;
  inherit (builtins)
    attrNames
    attrValues
    concatMap
    concatStringsSep
    elem
    elemAt
    filter
    groupBy
    isString
    length
    mapAttrs
    toJSON
    typeOf
    ;
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets) genAttrs nameValuePair zipAttrs;
  inherit (lib.lists) singleton;
  inherit (lib.trivial) flip pipe;
  mkOpt =
    args:
    lib.mkOption (
      {
        internal = true;
        readOnly = true;
      }
      // args
    );
  # helper vars
  interfaces = pipe cfg.interfaces [
    attrValues
    (filter (x: x.enable))
  ];
  safeListToStr = flip pipe [
    (map (x: if isString x then toJSON x else typeOf x))
    (concatStringsSep ", ")
  ];
in
{
  options.x-banananetwork.routerVM.references = {

    interfaceGroupsReal = mkOpt {
      description = ''
        Map of all interface groups to their members.
      '';
      default = pipe interfaces [
        (concatMap (i: map (nameValuePair i.name) i.groups))
        (groupBy (m: m.value))
        (mapAttrs (_: concatMap (m: singleton m.name)))
      ];
    };

    interfaceGroups = mkOpt {
      description = ''
        Map of all interface groups to their members.

        The group "all" is created automatically.
        For technical reasons, for each interface a group with the same name is created for that interface alone.
      '';
      default =
        refCfg.interfaceGroupsReal
        // pipe interfaces [
          (map (i: i.name))
          (flip genAttrs singleton)
        ]
        // {
          all = map (i: i.name) interfaces;
        };
    };

    macToIPv4 = mkOpt {
      description = "mapping from known MAC addresses to their defined static addresses";
      default = pipe interfaces [
        (map (i: i.references.macToIPv4))
        zipAttrs
        (mapAttrs (
          mac: ips:
          assert assertMsg (length ips == 1) "Found multiple IPv4s for MAC ${mac}: ${safeListToStr ips}";
          elemAt ips 0
        ))
      ];
    };

  };

  config = {
    assertions = [
      (
        let
          known = map (x: x.name) interfaces;
          duplicated = pipe refCfg.interfaceGroupsReal [
            attrNames
            (filter (x: elem x known))
          ];
        in
        {
          assertion = duplicated == [ ];
          message = "Interface group names overlapping with interface names: ${toString duplicated}";
        }
      )
    ];
  };

}
