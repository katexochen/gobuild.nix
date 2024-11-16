{
  pkgs ? let
    flakeLock = builtins.fromJSON (builtins.readFile ./flake.lock);
    inherit (flakeLock.nodes.nixpkgs) locked;
  in import (builtins.fetchTree locked) { },
}:

let
  inherit (pkgs) lib stdenv;

  go = pkgs.go.overrideAttrs(old: {
    env.GOEXPERIMENT="cacheprog";
  });

  hooks = pkgs.callPackages ./hooks {
    inherit gobuild-nix-cacher;
    inherit go;
  };

  gobuild-nix-cacher = stdenv.mkDerivation {
    name = "gobuild-nix-cacher";
    src = ./gobuild-nix-cacher;
    nativeBuildInputs = [
      hooks.buildGo
      hooks.installGo
    ];
    meta.mainProgram = "gobuild-nix-cacher";
  };

  # Go package set containing build cache output & setup hooks for Go vendor
  goPackages = {
    # Contains build cache output
    "github.com/alecthomas/kong" = stdenv.mkDerivation {
      pname = "github.com/alecthomas/kong";
      version = "1.4.0";

      src = pkgs.fetchFromGitHub {
        owner = "alecthomas";
        repo = "kong";
        rev = "v1.4.0";
        hash = "sha256-xfjPNqMa5Qtah4vuSy3n0Zn/G7mtufKlOiTzUemzFcQ=";
      };

      nativeBuildInputs = [
        hooks.configureGoCache
        hooks.buildGo
        hooks.buildGoCacheOutputSetupHook
      ];
    };
  };

in
  stdenv.mkDerivation (finalAttrs: {
    name = "simple-package";

    src = ./fixtures/simple-package;

    nativeBuildInputs = [
      hooks.configureGoCache
      hooks.buildGo
      hooks.installGo
    ];

    buildInputs = [
      goPackages."github.com/alecthomas/kong"
    ];

    preBuild = ''
      export NIX_GOCACHE_OUT=$(mktemp -d)

      mkdir -p vendor/github.com/alecthomas
      cp ${finalAttrs.src}/modules.txt vendor/modules.txt
      ln -s ${goPackages."github.com/alecthomas/kong".src} vendor/github.com/alecthomas/kong
    '';
  })
