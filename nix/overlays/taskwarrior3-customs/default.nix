{ ... }@flakeArg:
{ ... }@systemArg:
final: prev: {
  taskwarrior3 = prev.taskwarrior3.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patch.patch ];
  });
}
