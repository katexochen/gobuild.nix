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

    "golang.org/x/sys@v0.27.0" = callPackage (
      {
        stdenv,
        hooks,
        fetchgit,
      }:
      stdenv.mkDerivation (finalAttrs: {
        pname = "golang.org/x/sys";
        version = "0.27.0";

        src = fetchgit {
          url = "https://go.googlesource.com/sys";
          rev = "v${finalAttrs.version}";
          hash = "sha256-+d5AljNfSrDuYxk3qCRw4dHkYVELudXJEh6aN8BYPhM=";
        };

        nativeBuildInputs = [
          hooks.configureGoCache
          hooks.buildGo
          hooks.buildGoCacheOutputSetupHook
          hooks.buildGoVendorOutputSetupHook
        ];
      })
    ) { };

    "golang.org/x/sys@v0.13.0" = callPackage (
      {
        stdenv,
        hooks,
        fetchgit,
      }:
      stdenv.mkDerivation (finalAttrs: {
        pname = "golang.org/x/sys";
        version = "0.13.0";

        src = fetchgit {
          url = "https://go.googlesource.com/sys";
          rev = "v${finalAttrs.version}";
          hash = "sha256-GLmTiL1Geuk+OuIdY++e5rzXpa6WMVgZ2D3cl/VBypA=";
        };

        nativeBuildInputs = [
          hooks.configureGoCache
          hooks.buildGo
          hooks.buildGoCacheOutputSetupHook
          hooks.buildGoVendorOutputSetupHook
        ];
      })
    ) { };

    "github.com/alecthomas/kong@v1.4.0" = callPackage (
      {
        stdenv,
        hooks,
        fetchFromGitHub,
      }:
      stdenv.mkDerivation {
        pname = "github.com/alecthomas/kong";
        version = "1.4.0";

        src = fetchFromGitHub {
          owner = "alecthomas";
          repo = "kong";
          rev = "v1.4.0";
          hash = "sha256-xfjPNqMa5Qtah4vuSy3n0Zn/G7mtufKlOiTzUemzFcQ=";
        };

        nativeBuildInputs = [
          hooks.configureGoCache
          hooks.buildGo
          hooks.buildGoCacheOutputSetupHook
          hooks.buildGoVendorOutputSetupHook
        ];
      }
    ) { };

    "github.com/fsnotify/fsnotify@v1.8.0" = callPackage (
      {
        stdenv,
        hooks,
        fetchFromGitHub,
        goPackages,

      }:
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
          hooks.configureGoVendor
          hooks.configureGoCache
          hooks.buildGo
          hooks.buildGoCacheOutputSetupHook
          hooks.buildGoVendorOutputSetupHook
        ];

        buildInputs = [
          goPackages."golang.org/x/sys@v0.13.0"
        ];
      }
    ) { };
  }
)
