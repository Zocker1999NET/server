# collect central configuration pieces of the whole flake here
{
  config,
  libBNet,
  ...
}:
{

  _class = "flake";

  # systems for which system-dependent outputs will be provided
  # reflects what I currently need & support
  systems = [
    "x86_64-linux"
  ];

}
