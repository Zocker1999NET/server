{
  lib,
  self,
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

  orderedInputs = pipe self.inputs [
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

  directFollowings = getAllFollowings self;

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

in
{
  _class = "flake";
  # TODO declare orderedInputs option
  # TODO add input updating script as package
  flake = {
    inherit orderedInputs;
  };
}
