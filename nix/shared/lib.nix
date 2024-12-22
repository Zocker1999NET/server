{ ... }@flakeArg:
{

  /*
    Concept of Shared Modules:

    - shared between NixOS & Home-Manager
    - useable for modules operating similar on both systems (e.g. of programs)
    - "config" always represents NixOS config
    -> useful for assertions like "if app is enabled, system opts must be"
    -> or warnings in similar cases

    Implementation:

    - in NixOS, module operate the same
    - in HM, module accesses app settings from HM & other configs from NixOS
      -> for cross-checkings
  */

  forHM = module: cfg: { osConfig, ... }@args: module cfg (args // { config = osConfig; });

  forNixOS =
    module: cfg: args:
    module cfg args;

}
