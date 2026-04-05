# TODO upstream
# ref: https://github.com/NixOS/nix/blob/1dc45e994690a40203088e8376213c02e5998c47/src/libflake/include/nix/flake/flakeref.hh#L127
{ config, lib, ... }:
let
  inherit (builtins) length filter match;
  inherit (lib.attrsets) filterAttrs mapAttrsToList;
  inherit (lib.trivial) pipe;

  # Regex pattern for valid flake IDs as defined in Nix
  # Must start with a letter, followed by letters, digits, underscores, or hyphens
  # https://github.com/NixOS/nix/blob/1dc45e994690a40203088e8376213c02e5998c47/src/libflake/include/nix/flake/flakeref.hh#L127
  flakeIdRegex = "[a-zA-Z][a-zA-Z0-9_-]*";

  registry = config.nix.registry or { };

  # Find all invalid flake IDs using lib.trivial.pipe paradigm
  invalidIds = pipe registry [
    # Get all indirect registry entries (from.type == "indirect")
    (filterAttrs (name: value: value ? from && value.from ? type && value.from.type == "indirect"))
    # Extract the flake IDs (from.id attribute)
    (mapAttrsToList (name: value: value.from.id or null))
    # Filter out null IDs
    (filter (id: id != null))
    # Filter to only invalid IDs (those that don't match the regex)
    (filter (id: match flakeIdRegex id == null))
  ];
in
{
  _class = "nixos";
  config = {

    assertions = [
      {
        assertion = length invalidIds == 0;
        message = ''
          Invalid flake IDs in nix.registry: ${toString invalidIds}
          All flake IDs must match the regex "${flakeIdRegex}"
          (must start with a letter, followed by letters, digits, underscores, or hyphens)
        '';
      }
    ];

  };
}
