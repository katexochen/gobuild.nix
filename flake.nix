{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      forAllSystems = lib.genAttrs lib.systems.flakeExposed;

    in
    {
      legacyPackages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.callPackages ./package.nix { }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.callPackage ./shell.nix { };
        }
      );

      # Exposed for CI
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          filterDerivations = pkgs.lib.filterAttrs (n: v: pkgs.lib.isDerivation v);
          prefixNameWith = prefix: pkgs.lib.mapAttrs' (n: v: pkgs.lib.nameValuePair (prefix + n) v);
        in
        prefixNameWith "goPackages." (filterDerivations self.legacyPackages.${system}.goPackages)
        // (filterDerivations self.legacyPackages.${system})
      );
    };
}
