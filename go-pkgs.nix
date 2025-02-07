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
        rev ? null,
        buildInputs ? [ ],
        nativeBuildInputs ? [ ],
        ...
      }@args:
      let
        args' = lib.removeAttrs args [
          "hash"
          "rev"
          "buildInputs"
          "nativeBuildInputs"
        ];
      in
      stdenv.mkDerivation (
        finalAttrs:
        {
          inherit pname version;
          src =
            let
              owner-repo = lib.splitString "/" (lib.removePrefix "github.com/" pname);
              owner = builtins.elemAt owner-repo 0;
              repo = builtins.elemAt owner-repo 1;
            in
            fetchFromGitHub {
              inherit owner repo hash;
              rev = if rev != null then rev else "v${finalAttrs.version}";
            };
          nativeBuildInputs = [
            hooks.configureGoVendor
            hooks.configureGoCache
            hooks.buildGo
            hooks.buildGoCacheOutputSetupHook
            hooks.buildGoVendorOutputSetupHook
          ] ++ nativeBuildInputs;
          propagatedBuildInputs = buildInputs;
          dontInstall = true;
        }
        // args'
      )
    ) { };

    goVendorSrc = callPackage (
      { runCommand, findutils }:
      {
        src,
        ...
      }@args:
      runCommand (src.name or "source")
        {
          nativeBuildInputs = [ findutils ];
          version = args.version or src.rev;
        }
        ''
          cp -r ${src} $out
          chmod +w -R $out

          # Remove submodules from vendored sources
          find $out \
            -mindepth 2 \
            -type f \
            -name go.mod \
            -printf '%h\n' \
            | xargs rm -rf
        ''
    ) { };

    # Packages

    "_golang.org/x" = callPackage (
      {
        stdenv,
        hooks,
        fetchgit,
        goPackages,
        goVendorSrc,
      }:
      let
        srcs = {
          "golang.org/x/crypto" = fetchgit {
            name = "crypto";
            url = "https://go.googlesource.com/crypto";
            rev = "v0.32.0";
            hash = "sha256-LLt6IXv4jY3VRjnOT2Yw7Ca0oWCI3P49HDj2Fz887eI=";
          };
          "golang.org/x/exp" = goVendorSrc {
            src = fetchgit {
              name = "exp";
              url = "https://go.googlesource.com/exp";
              rev = "7588d65b2ba8549413779549f949cd7a5ccb1320";
              hash = "sha256-N1qhhNbR6N2RrZqMMLcBUYnF6M3pm8bqGJbp8E25kPA=";
            };
            version = "v0.0.0-20250106191152-7588d65b2ba8";
          };
          "golang.org/x/mod" = fetchgit {
            name = "mod";
            url = "https://go.googlesource.com/mod";
            rev = "v0.22.0";
            hash = "sha256-skiXXiDrO33eRHofDPJTFxnYNtsirJaoTpyeCvlrDco=";
          };
          "golang.org/x/net" = fetchgit {
            name = "net";
            url = "https://go.googlesource.com/net";
            rev = "v0.34.0";
            hash = "sha256-AZOLY4MUNxxDw5ZQtO9dmY/YRo1gFW87YvpX/eLTy4Q=";
          };
          "golang.org/x/sync" = fetchgit {
            name = "sync";
            url = "https://go.googlesource.com/sync";
            rev = "v0.10.0";
            hash = "sha256-HWruKClrdoBKVdxKCyoazxeQV4dIYLdkHekQvx275/o=";
          };
          "golang.org/x/sys" = fetchgit {
            name = "sys";
            url = "https://go.googlesource.com/sys";
            rev = "v0.29.0";
            hash = "sha256-TGDwlVIdOHHJevpXiH5XrE6nFBVOE+beixd+wcdZeBw=";
          };
          "golang.org/x/telemetry" = goVendorSrc {
            src = fetchgit {
              name = "telemetry";
              url = "https://go.googlesource.com/telemetry";
              rev = "04cd7bae618c3a771d5b69e5134b51345830b696";
              hash = "sha256-mXsCGO/W6HCZOqWNjjosu5zy77y4Siq4SQYrL/je0tY=";
            };
            version = "v0.0.0-20250117155846-04cd7bae618c";
          };
          "golang.org/x/term" = fetchgit {
            name = "term";
            url = "https://go.googlesource.com/term";
            rev = "v0.28.0";
            hash = "sha256-1/iWqndBRFgDL+/tVokkaGHpO/jdyjZ0dN2YWuBdiXQ=";
          };
          "golang.org/x/text" = fetchgit {
            name = "text";
            url = "https://go.googlesource.com/text";
            rev = "v0.21.0";
            hash = "sha256-m8LVnzj+VeclJflfgO7UcOSYSS052RvRgyjTXCgK8As=";
          };
          "golang.org/x/time" = fetchgit {
            name = "time";
            url = "https://go.googlesource.com/time";
            rev = "v0.9.0";
            hash = "sha256-ipaWVIk1+DZg0rfCzBSkz/Y6DEnB7xkX2RRYycHkhC0=";
          };
          "golang.org/x/tools" = goVendorSrc {
            src = fetchgit {
              name = "tools";
              url = "https://go.googlesource.com/tools";
              rev = "v0.29.0";
              hash = "sha256-h3UjRY1w0AyONADNiLhxXt9/z7Tb/40FJI8rKGXpBeM=";
            };
          };
          "golang.org/x/xerrors" = goVendorSrc {
            src = fetchgit {
              name = "xerrors";
              url = "https://go.googlesource.com/xerrors";
              rev = "a985d3407aa71f30cf86696ee0a2f409709f22e1";
              hash = "sha256-kj2qs47n+a4gtKXHJN3U9gcSQ3BozjzYu7EphXjJnwM=";
            };
            version = "v0.0.0-20190717185122-a985d3407aa7";
          };
        };
      in
      stdenv.mkDerivation (finalAttrs: {
        name = "golang.org/x";

        unpackPhase = ''
          runHook preUnpack

          mkdir -p workdir
          cd workdir
          go mod init golang-org-x-combined

          runHook postUnpack
        '';

        env.NIX_GO_VENDOR = lib.pipe srcs [
          (lib.mapAttrsToList (pname: src: "${pname}@${src.version or src.rev}:${src}"))
          (lib.concatStringsSep " ")
        ];

        nativeBuildInputs = [
          hooks.configureGoVendor
          hooks.configureGoCache
          goPackages.go
        ];

        propagatedBuildInputs = [
          goPackages."github.com/google/go-cmdtest"
          goPackages."github.com/google/go-cmp"
          goPackages."github.com/google/renameio"
          goPackages."github.com/yuin/goldmark"
        ];

        buildPhase =
          ''
            runHook preBuild

            export GO_NO_VENDOR_CHECKS=1
            export HOME=$(mktemp -d)
            mkdir -p "$out/nix-support"
          ''
          + (lib.pipe srcs [
            (lib.mapAttrsToList (
              pname: src: ''
                echo "Building ${pname}/..."
                go build ${pname}/...

                cat >>"$out/nix-support/setup-hook" <<EOF
                appendToVar NIX_GO_VENDOR "${pname}@${src.version or src.rev}:${src}"
                EOF
              ''
            ))
            (lib.concatStringsSep "\n")
          ])
          + ''
            runHook postBuild
          '';

        passthru = {
          inherit srcs;
        };
      })
    ) { };
    # TODO: only include propagatedBuildInputs that are actually required for the packages.
    "golang.org/x/crypto" = callPackage ({ goPackages }: goPackages."_golang.org/x") { };
    "golang.org/x/exp" = callPackage ({ goPackages }: goPackages."_golang.org/x") { };
    "golang.org/x/mod" = callPackage ({ goPackages }: goPackages."_golang.org/x") { };
    "golang.org/x/net" = callPackage ({ goPackages }: goPackages."_golang.org/x") { };
    "golang.org/x/sys" = callPackage ({ goPackages }: goPackages."_golang.org/x") { }; # has no dependencies, can be removed from x set.
    "golang.org/x/sync" = callPackage ({ goPackages }: goPackages."_golang.org/x") { }; # has no dependencies, can be removed from x set.
    "golang.org/x/telemetry" = callPackage ({ goPackages }: goPackages."_golang.org/x") { };
    "golang.org/x/term" = callPackage ({ goPackages }: goPackages."_golang.org/x") { };
    "golang.org/x/text" = callPackage ({ goPackages }: goPackages."_golang.org/x") { };
    "golang.org/x/time" = callPackage ({ goPackages }: goPackages."_golang.org/x") { }; # has no dependencies, can be removed from x set.
    "golang.org/x/tools" = callPackage ({ goPackages }: goPackages."_golang.org/x") { };
    "golang.org/x/xerrors" = callPackage ({ goPackages }: goPackages."_golang.org/x") { }; # has no dependencies, can be removed from x set.

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
      {
        mkGoModule,
        goPackages,
        systemdLibs,
      }:
      mkGoModule {
        pname = "github.com/coreos/go-systemd/v22";
        version = "22.5.0";
        hash = "sha256-ztvSLbLaKUe/pNIzKhjkVhKOdk8C9Xwr6jZxizgjC+4=";
        buildInputs = [
          goPackages."github.com/godbus/dbus/v5"
          systemdLibs
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
        version = "1.2.5";
        hash = "sha256-Cgw+BEGuiI+Cq40ojBuAGHZuYAQsPI5eoRaHfaYs6PQ=";
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
        version = "1.1.3-0.20240916144458-20a13a1f6b7c";
        rev = "20a13a1f6b7cb47a126dcb75152e21e1383bbaba";
        hash = "sha256-cGx2/0QQay46MYGZuamFmU0TzNaFyaO+J7Ddzlr/3dI=";
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
    "github.com/google/go-cmdtest" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/google/go-cmdtest";
        version = "0.3.0";
        hash = "sha256-l+aQ89PkKWUWhcZw2GaaAV6ZOdwD/vTUSxJ9sPVP0+8=";
        buildInputs = [
          goPackages."github.com/google/go-cmp"
          goPackages."github.com/google/renameio"
        ];
      }
    ) { };
    "github.com/google/renameio" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/google/renameio";
        version = "1.0.1";
        hash = "sha256-RS3xKcImH4gP5c02aEzf3cIlo1kmkUge9rjbpLIlyOI=";
      }
    ) { };
    "" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "";
        version = "";
        hash = "";
      }
    ) { };
  }
)
