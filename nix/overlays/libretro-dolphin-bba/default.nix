{ ... }@flakeArg:
{ ... }@systemArg:
final: prev: {
  # TODO remove on issues, esp. when upgrading to NixOS 26.05
  # reason: upstream gained support for adding network adapters
  # in https://github.com/libretro/dolphin/commit/a3b63e56df8f88ea91db7cc9d22fd557f4bbb4f5
  #  -> this patch is no longer required
  libretro = prev.libretro // {
    dolphin = prev.libretro.dolphin.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./patch.patch ];
    });
  };
}
