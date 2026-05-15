{
  flake,
  ...
}:
{
  _class = "nixos";
  config = {
    system.configurationRevision = toString (
      flake.shortRev or flake.dirtyShortRev or flake.lastModified or "unknown"
    );
  };
}
