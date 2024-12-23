{
  go,
  newScope,
  lib,
}:
lib.makeScope newScope (
  final:
  let
    inherit (final) callPackage;
  in
  {
    # Tooling

    inherit go;

    goPackages = final;

    # Fetch source of a Go package from Go proxy.
    fetchFromGoProxy = callPackage (
      { runCommandNoCC, go }:
      {
        pname,
        version,
        hash,
      }:
      runCommandNoCC "goproxy-${pname}-${version}"
        {
          buildInputs = [ go ];
          outputHashMode = "recursive";
          outputHashAlgo = "sha256";
          outputHash = hash;
        }
        ''
          export HOME=$TMPDIR
          export GOMODCACHE=$out
          export GOPROXY=https://proxy.golang.org
          go mod download ${pname}@v${version}
        ''
    ) { };

    # Build a Go package that was fetched with fetchFromGoProxy.
    mkGoModule = callPackage (
      {
        stdenv,
        fetchFromGoProxy,
        hooks,
      }:
      {
        pname,
        version,
        hash,
        buildInputs ? [ ],
        env ? { },
      }:
      stdenv.mkDerivation {
        inherit
          pname
          version
          buildInputs
          env
          ;
        src = fetchFromGoProxy { inherit pname version hash; };
        nativeBuildInputs = [
          hooks.configureGoVendor
          hooks.configureGoCache
          hooks.buildGo
          hooks.buildGoCacheOutputSetupHook
          hooks.buildGoVendorOutputSetupHook
        ];
        postPatch = ''
          cd ${pname}@v${version}
        '';
      }
    ) { };

    gobuild-nix-cacher = callPackage (
      { stdenv, hooks }:
      stdenv.mkDerivation {
        name = "gobuild-nix-cacher";
        src = ./gobuild-nix-cacher;
        nativeBuildInputs = [
          hooks.buildGo
          hooks.installGo
        ];
        meta.mainProgram = "gobuild-nix-cacher";
      }
    ) { };

    hooks = callPackage ./hooks { };

    # Packages

    "golang.org/x/sys" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "golang.org/x/sys";
        version = "0.27.0";
        hash = "sha256-DbcRkDeTPyapsS+sZCY+j1AEWm0pyFkK8VmbdudYeeA=";
      }
    ) { };

    "github.com/alecthomas/repr" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/alecthomas/repr";
        version = "0.4.0";
        hash = "sha256-H5TjyrYaclxAa8C+TXIjrJOTxGGvm7DJtMTuonQRQdk=";
      }
    ) { };

    "github.com/hexops/gotextdiff" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/hexops/gotextdiff";
        version = "1.0.3";
        hash = "sha256-c4Gvo7aWaQPTFb4N4iaw/7wxbZA0HMTXghAwwYyJtSM=";
      }
    ) { };

    "github.com/alecthomas/assert/v2" = callPackage (
      {
        mkGoModule,
        goPackages,
        symlinkJoin,
      }:
      mkGoModule rec {
        pname = "github.com/alecthomas/assert/v2";
        version = "2.11.0";
        hash = "sha256-OB2Y3u+q5n4Yx01NPEk9A8c9Qdb46yAWezkHQeW/WuM=";
        env.GOPROXY = "file://${
          symlinkJoin {
            name = "go-proxy-for-${pname}";
            paths = [
              goPackages."github.com/alecthomas/repr".src
              goPackages."github.com/hexops/gotextdiff".src
            ];
          }
        }/cache/download";
        buildInputs = [
          goPackages."github.com/alecthomas/repr"
          goPackages."github.com/hexops/gotextdiff"
        ];
      }
    ) { };

    "github.com/alecthomas/kong" = callPackage (
      {
        mkGoModule,
        goPackages,
        symlinkJoin,
      }:
      mkGoModule rec {
        pname = "github.com/alecthomas/kong";
        version = "1.4.0";
        hash = "sha256-eV2AIiR0exPixzCPwUiSEDeyxR2yQyVz8Gou8GuPEN0=";
        env.GOPROXY = "file://${
          symlinkJoin {
            name = "go-proxy-for-${pname}";
            paths = [
              goPackages."github.com/alecthomas/repr".src
              goPackages."github.com/hexops/gotextdiff".src
              goPackages."github.com/alecthomas/assert/v2".src
            ];
          }
        }/cache/download";
        buildInputs = [
          goPackages."github.com/alecthomas/repr"
          goPackages."github.com/hexops/gotextdiff"
          goPackages."github.com/alecthomas/assert/v2"
        ];
      }
    ) { };

    "github.com/fsnotify/fsnotify" = callPackage (
      {
        stdenv,
        hooks,
        fetchFromGitHub,
        goPackages,
        symlinkJoin,
      }:
      stdenv.mkDerivation rec {
        pname = "github.com/fsnotify/fsnotify";
        version = "1.8.0";

        src = fetchFromGitHub {
          owner = "fsnotify";
          repo = "fsnotify";
          rev = "v1.8.0";
          hash = "sha256-+Rxg5q17VaqSU1xKPgurq90+Z1vzXwMLIBSe5UsyI/M=";
        };

        nativeBuildInputs = [
          hooks.configureGoVendor
          hooks.configureGoCache
          hooks.buildGo
          hooks.buildGoCacheOutputSetupHook
        ];

        env.GOPROXY = "file://${
          symlinkJoin {
            name = "go-proxy-for-${pname}";
            paths = [
              goPackages."golang.org/x/sys".src
            ];
          }
        }/cache/download";

        buildInputs = [
          goPackages."golang.org/x/sys"
        ];
      }
    ) { };
  }
)
