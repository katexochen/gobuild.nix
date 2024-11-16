{
  pkgs ?
    let
      flakeLock = builtins.fromJSON (builtins.readFile ./flake.lock);
      inherit (flakeLock.nodes.nixpkgs) locked;
    in
    import (builtins.fetchTree locked) { },
}:

let
  go = pkgs.go.overrideAttrs (old: {
    env.GOEXPERIMENT = "cacheprog";
  });

  hooks = pkgs.callPackages ./hooks { inherit go; };

  cacher = pkgs.stdenv.mkDerivation {
    name = "gobuild-nix-cacher";
    src = ./gobuild-nix-cacher;
    nativeBuildInputs = [
      hooks.buildGo
      hooks.installGo
    ];
    meta.mainProgram = "gobuild-nix-cacher";
  };

in

pkgs.mkShell {
  packages = [
    go
    (import ./package.nix { inherit pkgs; })
    cacher
  ];

  env = {
    GOEXPERIMENT = "cacheprog";
    GOCACHEPROG = pkgs.lib.getExe cacher;
  };

  #   NIX_GOCACHE = builtins.toString ./nix-gocache;
  #   NIX_GOCACHE_OUT = builtins.toString ./nix-gocache;
  #   NIX_GOCACHE_VERBOSE = "1";
  # };
}
