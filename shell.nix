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
  goPackages = pkgs.callPackage ./go-pkgs.nix {
    # Override Go with cache experiment (not required for 1.24+)
    go = pkgs.go.overrideAttrs (old: {
      env.GOEXPERIMENT = "cacheprog";
    });
  };

  cacher = goPackages.gobuild-nix-cacher;

in

pkgs.mkShell {
  packages = [
    goPackages.go
    cacher
  ];

  env = {
    GOEXPERIMENT = "cacheprog";
    # GOCACHEPROG = pkgs.lib.getExe cacher;
  };
}
