{
  writeShellApplication,
  # deps
  pdftk,
  unixtools,
  ...
}:
let
  inherit (builtins) readFile;
in
writeShellApplication {
  name = "pdfpagecount";
  runtimeInputs = [
    pdftk
    unixtools.column
  ];
  text = readFile ./pdfpagecount.sh;
}
