{
  pkgs ? let
    flakeLock = builtins.fromJSON (builtins.readFile ./flake.lock);
    inherit (flakeLock.nodes.nixpkgs) locked;
  in import (builtins.fetchTree locked) { },
}:

let
  go = pkgs.go.overrideAttrs(old: {
    env.GOEXPERIMENT="cacheprog";
  });
in

pkgs.mkShell {
  packages = [
    go
  ];

  # env = {
  #   GOEXPERIMENT="cacheprog";
  #   GODEBUG="gocachetest=1";
  #   GOCACHEPROG = builtins.toString ./go-tool-cache/go-cacher;
  #   NIX_GOCACHE = builtins.toString ./nix-gocache;
  #   NIX_GOCACHE_OUT = builtins.toString ./nix-gocache;
  #   NIX_GOCACHE_VERBOSE = "1";
  # };
}
