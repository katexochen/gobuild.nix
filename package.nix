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

  hooks = pkgs.callPackages ./hooks { inherit go; };

  cacher = stdenv.mkDerivation {
    name = "gocache";
    src = ./gobuild-nix-cacher;
    nativeBuildInputs = [
      hooks.buildGo
      hooks.installGo
    ];

    meta.mainProgram = "gobuild-nix-cacher";
  };

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
        hooks.buildGo
        hooks.buildGoCacheOutputSetupHook
      ];

      env = {
        GOEXPERIMENT="cacheprog";
        GODEBUG="gocachetest=1";
        GOCACHEPROG = lib.getExe cacher;
        NIX_GOCACHE_VERBOSE = "1";
      };

      preBuild = ''
        export NIX_GOCACHE_OUT="$out"
      '';

      dontInstall = true;
    };
  };

in
  stdenv.mkDerivation (finalAttrs: {
    name = "simple-package";

    src = ./fixtures/simple-package;

    nativeBuildInputs = [
      hooks.buildGo
      hooks.installGo
    ];

    buildInputs = [
      goPackages."github.com/alecthomas/kong"
    ];

    env = {
      GOEXPERIMENT="cacheprog";
      GODEBUG="gocachetest=1";
      GOCACHEPROG = lib.getExe cacher;
      NIX_GOCACHE_VERBOSE = "1";
    };

    preBuild = ''
      export NIX_GOCACHE_OUT=$(mktemp -d)

      mkdir -p vendor/github.com/alecthomas
      cp ${finalAttrs.src}/modules.txt vendor/modules.txt
      ln -s ${goPackages."github.com/alecthomas/kong".src} vendor/github.com/alecthomas/kong
    '';
  })
