# TODO export as flake-parts module
{
  flake,
  lib,
  ...
}:
let
  inherit (builtins)
    attrNames
    attrValues
    concatLists
    elem
    filter
    import
    length
    mapAttrs
    ;
  inherit (lib.attrsets) genAttrs;
  inherit (lib.lists) sort uniqueStrings;
  inherit (lib.trivial) flip pipe;
in
rec {

  orderedInputs = pipe flake.inputs [
    attrNames
    (sort (a: b: a < b))
    (sort sortHelper)
  ];

  sortHelper =
    a: b:
    let
      bIsDependent = elem a recursiveFollowings.${b};
    in
    (recursiveFollowingCount.${a} < recursiveFollowingCount.${b}) || bIsDependent;

  recursiveFollowingCount = mapAttrs (_: length) recursiveFollowings;

  recursiveFollowings = pipe directFollowings [
    attrNames
    (flip genAttrs (
      input:
      let
        following = directFollowings.${input};
        followeds = map (followed: recursiveFollowings.${followed}) following;
      in
      uniqueStrings (following ++ concatLists followeds)
    ))
  ];

  directFollowings = getAllFollowings flake;

  getAllFollowings = flip pipe [
    (flake: import "${flake}/flake.nix")
    (raw: raw.inputs or { })
    (mapAttrs (_: getFollowing))
  ];

  getFollowing = flip pipe [
    (inputDecl: inputDecl.inputs or { })
    attrValues
    (filter (i: i ? follows))
    (map (i: i.follows))
  ];

}
