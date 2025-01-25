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

    mkGoModule = callPackage (
      {
        lib,
        stdenv,
        hooks,
        fetchFromGitHub,
      }:
      {
        pname,
        hash,
        version,
        buildInputs ? [ ],
      }:
      stdenv.mkDerivation (finalAttrs: {
        inherit pname version;
        src =
          let
            owner-repo = lib.splitString "/" (lib.removePrefix "github.com/" pname);
            owner = builtins.elemAt owner-repo 0;
            repo = builtins.elemAt owner-repo 1;
          in
          fetchFromGitHub {
            inherit owner repo hash;
            rev = "v${finalAttrs.version}";
          };
        nativeBuildInputs = [
          hooks.configureGoVendor
          hooks.configureGoCache
          hooks.buildGo
          hooks.buildGoCacheOutputSetupHook
          hooks.buildGoVendorOutputSetupHook
        ];
        inherit buildInputs;
      })
    ) { };

    # Packages

    "golang.org/x/sys" = callPackage (
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
    "golang.org/x/tools" = callPackage (
      {
        stdenv,
        hooks,
        fetchgit,
        goPackages,
      }:
      stdenv.mkDerivation (finalAttrs: {
        pname = "golang.org/x/tools";
        version = "0.29.0";
        src = fetchgit {
          url = "https://go.googlesource.com/tools";
          rev = "v${finalAttrs.version}";
          hash = "sha256-h3UjRY1w0AyONADNiLhxXt9/z7Tb/40FJI8rKGXpBeM=";
        };
        nativeBuildInputs = [
          hooks.configureGoVendor
          hooks.configureGoCache
          hooks.buildGo
          hooks.buildGoCacheOutputSetupHook
          hooks.buildGoVendorOutputSetupHook
        ];
        buildInputs = [
          goPackages."golang.org/x/sys"
          goPackages."github.com/google/go-cmp"
          goPackages."github.com/yuin/goldmark"
          goPackages."golang.org/x/mod"
          goPackages."golang.org/x/net"
          goPackages."golang.org/x/sync"
          goPackages."golang.org/x/telemetry"
        ];
      })
    ) { };
    "golang.org/x/mod" = callPackage (
      {
        stdenv,
        hooks,
        fetchgit,
      }:
      stdenv.mkDerivation (finalAttrs: {
        pname = "golang.org/x/mod";
        version = "0.22.0";
        src = fetchgit {
          url = "https://go.googlesource.com/mod";
          rev = "v${finalAttrs.version}";
          hash = "sha256-skiXXiDrO33eRHofDPJTFxnYNtsirJaoTpyeCvlrDco=";
        };
        nativeBuildInputs = [
          hooks.configureGoVendor
          hooks.configureGoCache
          hooks.buildGo
          hooks.buildGoCacheOutputSetupHook
          hooks.buildGoVendorOutputSetupHook
        ];
        # Required according to go.mod.
        # buildInputs = [
        #   goPackages."golang.org/x/tools"
        # ];
      })
    ) { };
    "golang.org/x/net" = callPackage (
      {
        stdenv,
        hooks,
        fetchgit,
        goPackages,
      }:
      stdenv.mkDerivation (finalAttrs: {
        pname = "golang.org/x/mod";
        version = "0.34.0";
        src = fetchgit {
          url = "https://go.googlesource.com/net";
          rev = "v${finalAttrs.version}";
          hash = "";
        };
        nativeBuildInputs = [
          hooks.configureGoVendor
          hooks.configureGoCache
          hooks.buildGo
          hooks.buildGoCacheOutputSetupHook
          hooks.buildGoVendorOutputSetupHook
        ];
        buildInputs = [
          goPackages."golang.org/x/crypto"
          goPackages."golang.org/x/sys"
          goPackages."golang.org/x/term"
          goPackages."golang.org/x/text"
        ];
      })
    ) { };
    "golang.org/x/text" = callPackage (
      {
        stdenv,
        hooks,
        fetchgit,
        goPackages,
      }:
      stdenv.mkDerivation (finalAttrs: {
        pname = "golang.org/x/text";
        version = "0.21.0";
        src = fetchgit {
          url = "https://go.googlesource.com/text";
          rev = "v${finalAttrs.version}";
          hash = "sha256-m8LVnzj+VeclJflfgO7UcOSYSS052RvRgyjTXCgK8As=";
        };
        nativeBuildInputs = [
          hooks.configureGoVendor
          hooks.configureGoCache
          hooks.buildGo
          hooks.buildGoCacheOutputSetupHook
          hooks.buildGoVendorOutputSetupHook
        ];
        buildInputs = [
          # goPackages."golang.org/x/tools" # Infinitely recursive.
        ];
      })
    ) { };

    "github.com/alecthomas/kong" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/alecthomas/kong";
        version = "1.4.0";
        hash = "sha256-xfjPNqMa5Qtah4vuSy3n0Zn/G7mtufKlOiTzUemzFcQ=";
      }
    ) { };
    "github.com/fsnotify/fsnotify" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/fsnotify/fsnotify";
        version = "1.8.0";
        hash = "sha256-+Rxg5q17VaqSU1xKPgurq90+Z1vzXwMLIBSe5UsyI/M=";
        buildInputs = [
          goPackages."golang.org/x/sys"
        ];
      }
    ) { };
    "github.com/rs/zerolog" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/rs/zerolog";
        version = "1.33.0";
        hash = "sha256-d8lSZ9MuQzAsqdijQ7gHx0Sci9ysMfb3RWGiYJPX5ZE=";
        buildInputs = [
          goPackages."github.com/coreos/go-systemd/v22"
          goPackages."github.com/mattn/go-colorable"
          goPackages."github.com/mattn/go-isatty"
          goPackages."github.com/pkg/errors"
          goPackages."github.com/rs/xid"
          goPackages."golang.org/x/sys"
        ];
      }
    ) { };
    "github.com/rs/xid" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/rs/xid";
        version = "1.6.0";
        hash = "sha256-rJB7h3KuH1DPp5n4dY3MiGnV1Y96A10lf5OUl+MLkzU=";
      }
    ) { };
    "github.com/spf13/pflag" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/spf13/pflag";
        version = "1.0.5";
        hash = "sha256-YTRLqLRZJHBh2m1dA99/EepY3DAi/rks1feB9ixT9T4=";
      }
    ) { };
    "github.com/pkg/errors" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/pkg/errors";
        version = "0.9.1";
        hash = "sha256-mNfQtcrQmu3sNg/7IwiieKWOgFQOVVe2yXgKBpe/wZw=";
      }
    ) { };
    "github.com/mattn/go-isatty" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/mattn/go-isatty";
        version = "0.0.20";
        hash = "sha256-6sX3ZvuVi8/3DAU1+8zN9IUpUdtT2JqwxSGldXmywzw=";
        buildInputs = [
          goPackages."golang.org/x/sys"
        ];
      }
    ) { };
    "github.com/mattn/go-colorable" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/mattn/go-colorable";
        version = "0.1.14";
        hash = "sha256-V32P6V2arwSQo5Uesps14tJPu9sQNq0OPb8ZvhJXJXM=";
        buildInputs = [
          goPackages."golang.org/x/sys"
          goPackages."github.com/mattn/go-isatty"
        ];
      }
    ) { };
    "github.com/coreos/go-systemd/v22" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/coreos/go-systemd/v22";
        version = "22.5.0";
        hash = "sha256-ztvSLbLaKUe/pNIzKhjkVhKOdk8C9Xwr6jZxizgjC+4=";
        buildInputs = [
          goPackages."github.com/godbus/dbus/v5"
        ];
      }
    ) { };
    "github.com/godbus/dbus/v5" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/godbus/dbus/v5";
        version = "5.1.0";
        hash = "sha256-JSPtmkGEStBEVrKGszeLCb7P38SzQKgMiDC3eDppXs0=";
        buildInputs = [
          goPackages."golang.org/x/sys"
        ];
      }
    ) { };
    "github.com/google/go-cmp" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/google/go-cmp";
        version = "0.6.0";
        hash = "sha256-qgra5jze4iPGP0JSTVeY5qV5AvEnEu39LYAuUCIkMtg=";
      }
    ) { };
    "github.com/Workiva/go-datastructures" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/Workiva/go-datastructures";
        version = "1.1.5";
        hash = "";
        buildInputs = [
          goPackages."github.com/stretchr/testify"
          goPackages."github.com/tinylib/msgp"
        ];
      }
    ) { };
    "github.com/tinylib/msgp" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/tinylib/msgp";
        version = "1.1.0";
        hash = "";
        buildInputs = [
          goPackages."github.com/philhofer/fwd"
          goPackages."golang.org/x/tools"
        ];
      }
    ) { };
    "github.com/philhofer/fwd" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/philhofer/fwd";
        version = "1.1.2";
        hash = "sha256-N+jWn8FSjVlb/OAWmvLTm2G5/ckIkhzSPePXoeymfyA=";
      }
    ) { };
    "github.com/yuin/goldmark" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/yuin/goldmark";
        version = "1.7.8";
        hash = "sha256-XXpz9CkA51e2HKWwOgiyqURBUKZIqcVmQ73HhmHo58c=";
      }
    ) { };
  }
)
