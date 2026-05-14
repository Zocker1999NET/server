{
  inputs,
  self,
  ...
}:
{
  _class = "flake";
  perSystem.nixosDocTests = {

    # === flake input extended/integration tests
    # (maybe upstream someday)

    # most basic, verifies my own testing method as already upstreamed
    nixpkgs = {
      modules = [ ]; # nixpkgs already included
    };
    # input-specific doc tests
    disko = {
      module = inputs.disko.nixosModules.disko;
      buildDocsInSandbox = false;
    };
    home-manager = {
      module = inputs.home-manager.nixosModules.home-manager;
    };
    impermanence = {
      module = inputs.impermanence.nixosModules.impermanence;
    };
    secrix = {
      module = inputs.secrix.nixosModules.secrix;
    };

    # == own module tests

    # all module doc test
    # - indicates missing dependency-specific test or failure in banananetwork module
    banananetwork = {
      modules = [
        self.nixosModules.withDepends # bnet modules require their dependencies
        self.nixosModules.myOptions
      ];
      buildDocsInSandbox = false;
    };

    # own home-manager module doc test
    hm_banananetwork = {
      modules = [
        inputs.home-manager.nixosModules.home-manager
        { home-manager.sharedModules = [ self.homeModules.default ]; }
      ];
    };

    router = {
      modules = [
        self.nixosModules.withDepends # router module requires that (TODO upstream those dependencies)
        self.nixosModules.router
      ];
      buildDocsInSandbox = false;
    };

  };
}
