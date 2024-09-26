# inefficient, but sufficient math functions missing in Nix & nixpkgs
{ lib, ... }@flakeArg:
let
  inherit (builtins) foldl' genList isInt;
  inherit (lib.lists) imap0 reverseList;
  inherit (lib.strings) stringToCharacters;
  inherit (lib.trivial) flip pipe;
in
rec {

  bitAsString = bool: if bool then "1" else "0";

  binToInt = flip pipe [
    stringToCharacters
    reverseList
    (imap0 (i: x: if x == "1" then pow 2 i else 0))
    (foldl' (a: v: a + v) 0)
  ];

  intToBin =
    len: num:
    assert isInt len && isInt num;
    let
      maxVal = pow 2 len;
      twoPowers = genList (i: pow 2 (len - 1 - i)) len;
      init = {
        number = num;
        output = "";
      };
      folder =
        { number, output }:
        power:
        let
          bit = number >= power;
        in
        {
          number = if bit then number - power else number;
          output = "${output}${bitAsString bit}";
        };
    in
    assert num < maxVal;
    (foldl' folder init twoPowers).output;

  pow = x: exp: foldl' (a: b: a * b) 1 (genList (_: x) exp); # TODO

}
