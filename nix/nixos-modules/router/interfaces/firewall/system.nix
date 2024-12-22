{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  fwCfg = ifCfg.firewall;
  # helpers
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
in
{

  options.firewall = {
    integrateSystemInputRules = mkOption {
      description = ''
        Whether to allow incoming traffic from this interface
        in accordance to "system" firewall rules.

        This utilizes the native NixOS input chain, hence incorporates input rules from:
        - `networking.firewall`, esp. `allowedTCPPorts` & `allowedUDPPorts`
        - hereby most of the `.openFirewall` directives

        None of the router-internal functionality depends on this setting.
        But be aware that you might block your SSH access when disabling this!
      '';
      type = lib.types.bool;
      default = true;
    };
  };

  # TODO NixOS test: when disabled, do not allow traffic
  config.firewall.inputRules = mkIf fwCfg.integrateSystemInputRules ''
    jump input-allow comment "NixOS system rules"
  '';

}
