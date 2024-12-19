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
      }:
      stdenv.mkDerivation {
        inherit pname version;
        src = fetchFromGoProxy { inherit pname version hash; };
        nativeBuildInputs = [
          hooks.configureGoCache
          hooks.buildGo
          hooks.buildGoCacheOutputSetupHook
        ];
        preBuild = ''
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

    "github.com/alecthomas/kong" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/alecthomas/kong";
        version = "1.4.0";
        hash = "sha256-UT1vOjMHpga1y2ZoLpb3OmncXSWUcfoULrdSvjnoB40=";
      }
    ) { };

    "github.com/fsnotify/fsnotify" = callPackage (
      {
        stdenv,
        hooks,
        fetchFromGitHub,
        goPackages,

      }:
      let
        sys = goPackages."golang.org/x/sys";
      in
      stdenv.mkDerivation {
        pname = "github.com/fsnotify/fsnotify";
        version = "1.8.0";

        src = fetchFromGitHub {
          owner = "fsnotify";
          repo = "fsnotify";
          rev = "v1.8.0";
          hash = "sha256-+Rxg5q17VaqSU1xKPgurq90+Z1vzXwMLIBSe5UsyI/M=";
        };

        nativeBuildInputs = [
          hooks.configureGoCache
          hooks.buildGo
          hooks.buildGoCacheOutputSetupHook
          go
        ];

        buildInputs = [
          sys
        ];

        # Automatically set GOPROXY via hook.
        # Override versions in go.mod files.
        preBuild = ''
          export GOPROXY=file://${sys.src}/cache/download
          export GOSUMDB=off

          # Override versions in go.mod files.
          export HOME=$TMPDIR
          go mod edit -replace=${sys.pname}=${sys.pname}@v${sys.version}
          go mod tidy
        '';
      }
    ) { };
  }
)
