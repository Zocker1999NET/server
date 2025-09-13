{ inputs, self, ... }@flakeArg:
let
  inherit (inputs) nixpkgs nixpkgs_unstable;
  inherit (nixpkgs) lib; # prevent infinite recursion
  inherit (builtins)
    getAttr
    hasAttr
    mapAttrs
    isString
    ;
  inherit (lib.attrsets) attrByPath hasAttrByPath updateManyAttrsByPath;
  inherit (lib.options) showOption;
  inherit (lib.strings) splitString;
  inherit (lib.trivial)
    flip
    pipe
    warn
    warnIf
    ;
  inherit (self) backportByPath;
in
{

  backportByPath =
    let
      pathInterpret = p: if isString p then splitString "." p else p;
    in
    new: orig: prefix:
    flip pipe [
      (map (
        path:
        let
          pathList = pathInterpret path;
          pathFull = pathInterpret prefix ++ pathList;
          error = abort "attr not found on path ${showOption pathFull}";
          newVal = attrByPath pathFull error new;
          origVal = attrByPath pathFull newVal orig;
        in
        {
          path = pathList;
          update =
            _:
            warnIf (hasAttrByPath pathFull orig)
              "backporting attribute ${showOption pathFull} no longer required"
              origVal;
        }
      ))
      (flip updateManyAttrsByPath { })
    ];

  backportNixpkg = backportByPath nixpkgs_unstable nixpkgs;

  backportingOverlay =
    backportPkgs: packageVersionMap: final: prev:
    let
      backportOne =
        name: until:
        let
          alreadyStable = hasAttr name prev && lib.versionAtLeast prev.lib.version until;
          stableSource = warn "consider removing ${name} from backports list as it is now available since ${until}" prev;
          source = if alreadyStable then stableSource else backportPkgs;
          pkg = getAttr name source;
        in
        pkg;
    in
    mapAttrs backportOne packageVersionMap;

}
