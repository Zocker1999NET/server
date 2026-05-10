# collect central configuration pieces of the whole flake here
{
  config,
  libBNet,
  self,
  ...
}:
{

  _class = "flake";

  # args intended for other module classes
  flakeSpecialArgs = {
    flake = self;
    flakeArg = config.allModuleArgs;
    inherit libBNet;
  };

  # systems for which system-dependent outputs will be provided
  # reflects what I currently need & support
  systems = [
    "x86_64-linux"
  ];

}
