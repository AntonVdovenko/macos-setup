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
      # `path:.` includes the ignored machine-local file. Pure Git evaluation
      # falls back to the neutral template so CI can still evaluate the flake.
      hostFile = if builtins.pathExists ./hosts/local.nix
        then ./hosts/local.nix
        else ./hosts/template.nix;
      host = import hostFile;
    in
    {
      darwinConfigurations.${host.configuration} = nix-darwin.lib.darwinSystem {
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
