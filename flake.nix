{
  description = "Anton's macOS configuration — nix-darwin + home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { self, nixpkgs, nix-darwin, home-manager }:
    let
      host = import ./hosts/vdovenko-mbp.nix;
    in
    {
      darwinConfigurations.${host.hostname} = nix-darwin.lib.darwinSystem {
        inherit (host) system;
        specialArgs = { inherit inputs host; };
        modules = [
          ./darwin
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              # Without this, first activation aborts rather than overwrite an
              # existing ~/.zshrc.
              backupFileExtension = "hm-backup";
              extraSpecialArgs = { inherit inputs host; };
              users.${host.username} = import ./home;
            };
          }
        ];
      };
    };
}
