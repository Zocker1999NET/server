{ lib, ... }@flakeArg:
let
  inherit (builtins)
    isAttrs
    isBool
    isList
    isNull
    isString
    match
    typeOf
    ;
  inherit (lib.strings) optionalString replaceString;
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

    escapeCSSFontFamily =
      arg:
      let
        string = toString arg;
      in
      if match "-?[_A-Za-z0-9][_A-Za-z0-9-]*" string == null then
        "'${replaceString "'" "'\\''" string}'"
      else
        string;

  };
}
