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
  goPackages = pkgs.callPackages ./go-pkgs.nix {
    # Override Go with cache experiment (not required for 1.24+)
    go = pkgs.go.overrideAttrs (old: {
      env.GOEXPERIMENT = "cacheprog";
    });
  };

in
{
  inherit goPackages;

  fsnotify =
    let
      base = goPackages."github.com/fsnotify/fsnotify";
    in
    pkgs.stdenv.mkDerivation {
      pname = "fsnotify";
      inherit (base) version src;

      buildInputs = [
        # base
        goPackages."golang.org/x/sys"
      ];

      nativeBuildInputs =
        let
          inherit (goPackages) hooks;
        in
        [
          hooks.configureGoCache
          hooks.buildGo
          hooks.installGo
        ];
    };

  simple-package = pkgs.stdenv.mkDerivation (finalAttrs: {
    name = "simple-package";

    src = ./fixtures/simple-package;

    nativeBuildInputs =
      let
        inherit (goPackages) hooks;
      in
      [
        hooks.configureGoCache
        hooks.buildGo
        hooks.installGo
      ];

    buildInputs = [
      goPackages."github.com/alecthomas/kong"
    ];
  });
}
