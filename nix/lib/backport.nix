{ inputs, self, ... }@flakeArg:
let
  inherit (inputs) nixpkgs nixpkgs_unstable;
  inherit (nixpkgs) lib; # prevent infinite recursion
  inherit (builtins) isString;
  inherit (lib.attrsets) attrByPath hasAttrByPath updateManyAttrsByPath;
  inherit (lib.options) showOption;
  inherit (lib.strings) splitString;
  inherit (lib.trivial) flip pipe warnIf;
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
            warnIf (hasAttrByPath pathFull orig) "${showOption pathFull} no longer needs to be backported"
              origVal;
        }
      ))
      (flip updateManyAttrsByPath { })
    ];

  backportNixpkg = backportByPath nixpkgs_unstable nixpkgs;

}
