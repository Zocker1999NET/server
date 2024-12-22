{ outputs, ... }@flakeArg:
{ ... }@systemArg:
final: prev: {
  libretro = prev.libretro // {
    dolphin = prev.libretro.dolphin.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./patch.patch ];
    });
  };
}
