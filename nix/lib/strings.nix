{ lib, ... }@flakeArg:
let
  inherit (builtins)
    isAttrs
    isBool
    isList
    isNull
    isString
    typeOf
    ;
  inherit (lib.strings) optionalString;
in
{
  _class = "flake";
  flake.lib.strings = {

    conditionalString =
      cond:
      optionalString (
        if isNull cond then
          false
        else if isBool cond then
          cond
        else if isString cond then
          cond != ""
        else if isList cond then
          cond != [ ]
        else if isAttrs cond then
          cond.enable or (cond != { })
        else
          throw "unexpected type of condition ${typeOf cond}"
      );

  };
}
