# backports nixos modules from unstable
{ inputs, ... }@flakeArg:
{
  config,
  lib,
  modulesPath,
  ...
}:
let
  nix_stable = "${modulesPath}";
  nix_unstable = "${inputs.nixpkgs_unstable}/nixos/modules";
  backport =
    { path, until }:
    if lib.versionAtLeast lib.version until then
      {
        config.warnings = [ "backporting module ${path} is no longer required on NixOS ${lib.version}" ];
      }
    else
      {
        disabledModules = lib.singleton "${nix_stable}/${path}";
        imports = lib.singleton "${nix_unstable}/${path}";
      };
in
{

  _class = "nixos";

  imports = map backport [
  ];

}
