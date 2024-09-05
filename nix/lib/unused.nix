{ lib, ... }@flakeArg:
# functions I wrote but didn’t end up using
# feel free to use them & reference them directly
{

  slaacSuffix =
    mac:
    let
      replaceChars = [
        " "
        "."
        ":"
        "-"
      ];
      rawMac = builtins.replaceStrings replaceChars (map (x: "") replaceChars) (lib.strings.toLower mac);
      invert7bit = {
        "0" = "2";
        "1" = "3";
        "2" = "0";
        "3" = "1";
        "4" = "6";
        "5" = "7";
        "6" = "4";
        "7" = "5";
        "8" = "a";
        "9" = "b";
        "a" = "8";
        "b" = "9";
        "c" = "e";
        "d" = "f";
        "e" = "c";
        "f" = "d";
      };
      inherit (builtins) substring;
    in
    assert builtins.match (lib.strings.replicate 12 "[0-9a-f]") rawMac;
    builtins.concatStringsSep "" [
      (substring 0 1 rawMac)
      (invert7bit.${substring 1 1 rawMac})
      (substring 2 2 rawMac)
      ":"
      (substring 4 2 rawMac)
      "ff:f0"
      (substring 6 2 rawMac)
      ":"
      (substring 8 4 rawMac)
    ];

}
