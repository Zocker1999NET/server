{ ... }@flakeArg:
{ config, lib, ... }:
let
  cfg = config.x-banananetwork.routerVM;
  ts = config.services.tailscale;
  inherit (lib.modules) mkIf;
  mkDisableOption = arg: (lib.mkEnableOption arg) // { default = true; };
  routerFlags = {
    # in general: do not mess with the router module
    # see https://tailscale.com/kb/1241/tailscale-up
    accept-dns = false; # do not overwrite local DNS settings
    exit-node = ""; # use interface routes to selectively route traffic through Tailscale
    netfilter-mode = "none"; # prevent Tailscale from modifying nftables at all
    snat-subnet-rules = false; # use interface options for applying SNAT
  };
in
{

  options.x-banananetwork.routerVM.compat.tailscale = {
    enable = mkDisableOption ''
      options ensuring compatibility with Tailscale.

      These assertions & options only affect options of the Tailscale module
      and are hereby only effective if the Tailscale module is configured.

      Only disable these compatibility options
      after you checked why those are set.
    '';
  };

  config = mkIf (cfg.enable && ts.enable && cfg.compat.tailscale.enable) {

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
          message = "--${name} in services.tailscale.${optionsName} is already configured by router settings & cannot be configured manually";
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
