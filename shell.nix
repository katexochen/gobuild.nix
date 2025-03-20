{
  pkgs ?
    let
      flakeLock = builtins.fromJSON (builtins.readFile ./flake.lock);
      inherit (flakeLock.nodes.nixpkgs) locked;
    in
    import (builtins.fetchTree locked) { },
}:

let

  # Go package set containing build cache output & hooks
  goPackages = pkgs.callPackage ./go-pkgs.nix { };

  cacher = goPackages.gobuild-nix-cacher;

in

pkgs.mkShell {
  packages = [
    goPackages.go
    cacher
    pkgs.nixfmt-rfc-style
  ];

  env = {
    # GOCACHEPROG = pkgs.lib.getExe cacher;
  };
}
