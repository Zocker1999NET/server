{
  pkgs,
  ...
}:
let
  inherit (pkgs) runCommand;
  # TODO upstream
  # copies file into its own derivation
  copyFile =
    name: path:
    runCommand name { } ''
      cp -v ${path} "$out"
    '';
in
{

  # _class = "homeManager.vscodeProfile";

  extensions = with pkgs.vscode-extensions; [
    streetsidesoftware.code-spell-checker
    streetsidesoftware.code-spell-checker-german
  ];

  userSettings = {
    "cSpell.allowCompoundWords" = false; # enforce camelCasing or snake_casing
    "cSpell.customDictionaries" =
      let
        createDict = name: path: {
          inherit name;
          path = copyFile "cSpell-dict-${name}" path;
          scope = "user";
          addWords = false;
        };
      in
      {
        bnet = createDict "bnet" ../../cspell-dicts/bnet.txt;
        nix = createDict "nix" ../../cspell-dicts/nix.txt;
        python = createDict "python" ../../cspell-dicts/python.txt;
        terms = createDict "terms" ../../cspell-dicts/terms.txt;
        # editable dict
        inbox = {
          name = "inbox";
          path = "~/projects/server/nix/nixosModules/frontend/cspell-dicts/inbox.txt";
          scope = "user";
          addWords = true;
        };
      };
    "cSpell.language" = "en,de";
    "cSpell.languageSettings" = [
      {
        "caseSensitive" = false; # because of package names
        "languageId" = [ "nix" ];
      }
    ];
    "cSpell.spellCheckDelayMs" = 5000; # increase delay to reduce CPU usage, especially for large files
  };

}
