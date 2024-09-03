# TODO until https://github.com/systemd/systemd/issues/29651 is fixed
{ outputs, ... }@flakeArg:
{ ... }@systemArg:
final: prev: {
  systemd = prev.systemd.overrideAttrs (old: {
    patches = old.patches ++ [ ./patch.patch ];
  });
}
