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
    pkgs.stdenv.mkDerivation rec {
      pname = "fsnotify";
      inherit (base) version src;

      env.GOPROXY = "file://${
        pkgs.symlinkJoin {
          name = "go-proxy-for-${pname}";
          paths = [
            goPackages."golang.org/x/sys".src
          ];
        }
      }/cache/download";

      buildInputs = [
        goPackages."golang.org/x/sys"
        base
      ];

      nativeBuildInputs =
        let
          inherit (goPackages) hooks;
        in
        [
          hooks.configureGoVendor
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
        hooks.configureGoVendor
        hooks.configureGoCache
        hooks.buildGo
        hooks.installGo
      ];

    env.GOPROXY = "file://${
      pkgs.symlinkJoin {
        name = "go-proxy-for-${finalAttrs.name}";
        paths = [
          goPackages."github.com/alecthomas/repr".src
          goPackages."github.com/hexops/gotextdiff".src
          goPackages."github.com/alecthomas/assert/v2".src
          goPackages."github.com/alecthomas/kong".src
        ];
      }
    }/cache/download";

    buildInputs = [
      goPackages."github.com/alecthomas/kong"
    ];
  });
}
