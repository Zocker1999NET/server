# TODO WORK IN PROGESS
{ config, lib, ... }:
let
  # TODO either escape names in config out properly OR filter in type def for allowed characters
  bindCfg = config.services.bind;
  inherit (lib) types;
  inherit (lib.options) mkOption;
  # types
  viewMod =
    { config, name, ... }:
    {
      options = {
        priority = mkOption {
          description = ''
            Defines the matching priority of this view.

            All views are ordered as follows:
            - first all numeric values, from lowest (possibly negative) to highest
            - then all string values, as ordered by Nix native `<`
          '';
          type = types.oneOf types.int types.str;
          default = name;
          example = 10;
        };
        name = mkOption {
          description = "Name of the view.";
          type = types.nonEmptyStr;
          default = name;
          example = "internal";
        };
        zones = mkOption {
          description = "Zones accessibly in the view.";
          type = types.attrsOf (types.submodule zoneMod);
          default = { };
        };
        # TODO migrate to Nix-native type definitions
        extras = mkOption {
          description = "Extra lines which will be added to the view’s definition.";
          type = types.lines;
          default = "";
        };
        # output
        definition = mkOption {
          internal = true;
          readOnly = true;
          description = "complete definition of view";
          type = types.str;
        };
      };
      config.definition = ''
        view "${config.name}" {
          ${config.extras}
        }
      '';
    };
  zoneMod =
    { config, name, ... }:
    {
      options = {

      };
    };
in
{

  _class = "nixos";

  options.services.bind = {
    views = mkOption {
      description = ''
        Ressembling BIND views.

        The order of the views is determined by their `.priority` attribute.
        Their order is relevant for the matching priority.
      '';
      type = types.attrsOf (types.submodule viewMod);
      default = { };
    };
  };

  config = {
    services.bind = {

    };
  };

}
