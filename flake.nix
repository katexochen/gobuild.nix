{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:katexochen/nixpkgs?ref=mp/go-fix-vendor-load";
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

      # Exposed for garnix CI.
      # Currently, dots are not allowed in package names,
      # see https://github.com/garnix-io/issues/issues/104.
      # Also builds of legacyPackages are not supported yet,
      # see https://github.com/garnix-io/issues/issues/92.
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          filterDerivations = pkgs.lib.filterAttrs (n: v: pkgs.lib.isDerivation v);
          prefixNameWith = prefix: pkgs.lib.mapAttrs' (n: v: pkgs.lib.nameValuePair (prefix + n) v);
          removeDotsFromName = pkgs.lib.mapAttrs' (
            n: v: pkgs.lib.nameValuePair (lib.replaceStrings [ "." ] [ "-" ] n) v
          );
        in
        prefixNameWith "goPackages-" (
          removeDotsFromName (filterDerivations self.legacyPackages.${system}.goPackages)
        )
        // (filterDerivations self.legacyPackages.${system})

      );
    };
}
