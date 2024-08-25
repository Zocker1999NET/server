{ ... }@flakeArg:
{

  # combination of all my custom modules
  # these should not change anything until you enable their custom options
  default.imports = [
    # directories
    ./extends
  ];

}
