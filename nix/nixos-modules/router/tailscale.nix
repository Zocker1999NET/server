{ ... }@flakeArg:
{ config, lib, ... }:
let
  cfg = config.x-banananetwork.routerVM;
  ts = config.services.tailscale;
  routerFlags = {
    # do not mess with the router module
    accept-dns = false;
    exit-node = "";
    netfilter-mode = "none";
    snat-subnet-rules = false;
  };
in
{

  config = lib.mkIf (cfg.enable && ts.enable) {

    assertions =
      let
        isOptSetOnce =
          optName: options:
          let
            trace = pref: val: lib.trace "${pref} = ${builtins.toJSON val}" val;
            nameRegex = "^--${lib.escapeRegex optName}(=.*)?$";
            matchOpt = text: builtins.match nameRegex text != null;
            matched = trace "matched" (builtins.filter matchOpt options);
          in
          builtins.length matched <= 1;
        assertOpt = optionsName: options: name: {
          assertion = isOptSetOnce name options;
          message = "--${name} in services.tailscale.${optionsName} is already configured by router settings";
        };
        assertSetOpt = assertOpt "extraSetFlags" ts.extraSetFlags;
      in
      [
        {
          assertion = ts.useRoutingFeatures == "none";
          message = "services.tailscale.useRoutingFeatures will break security gurantees on a router, divert to manual configuration via router options";
        }
      ]
      ++ map assertSetOpt (builtins.attrNames routerFlags);

    services.tailscale = {
      setFlags = routerFlags;
    };

  };

}
