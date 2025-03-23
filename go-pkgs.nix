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
        fetchFromGoProxy,
      }:
      {
        pname,
        hash ? null,
        version,
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
          src = fetchFromGoProxy {
            inherit hash;
            importPath = pname;
            version = "v${version}";
          };
          nativeBuildInputs = [
            hooks.makeGoDependency
          ] ++ nativeBuildInputs;
          propagatedBuildInputs = buildInputs;
        }
        // args'
      )
    ) { };

    # Fetch source of a Go package from Go proxy.
    fetchFromGoProxy = callPackage ./fetch-from-go-proxy.nix { };

    # Packages

    "_golang.org/x" = callPackage (
      {
        stdenv,
        hooks,
        goPackages,
        fetchFromGoProxy,
      }:
      let
        srcs = {
          "golang.org/x/crypto" = fetchFromGoProxy {
            importPath = "golang.org/x/crypto";
            version = "v0.32.0";
            hash = "sha256-+cMpGGiaNKSVb0P/CSSZtxBNc2lZnivzD2ClIwlImEY=";
          };
          "golang.org/x/exp" = fetchFromGoProxy {
            importPath = "golang.org/x/exp";
            version = "v0.0.0-20250106191152-7588d65b2ba8";
            hash = "sha256-jb7yfzbFBxbr24mrql5PUKMHxsHZLbo8Kp5w8/igrTI=";
          };
          "golang.org/x/mod" = fetchFromGoProxy {
            importPath = "golang.org/x/mod";
            version = "v0.22.0";
            hash = "sha256-Gw+3Nxa+bNKqVtPggQWdrFYVBjbb1XkmY8c6GICozPU=";
          };
          "golang.org/x/net" = fetchFromGoProxy {
            importPath = "golang.org/x/net";
            version = "v0.34.0";
            hash = "sha256-obDSk+obB3o9FvbmstVho8+IDrPnp9tVPnwuRhB2z0g=";
          };
          "golang.org/x/telemetry" = fetchFromGoProxy {
            importPath = "golang.org/x/telemetry";
            version = "v0.0.0-20250117155846-04cd7bae618c";
            hash = "sha256-0pQI6Ike92VDZB+gA5WOp8d7tbaAtGnyggcMYh+JpGs=";
          };
          "golang.org/x/term" = fetchFromGoProxy {
            importPath = "golang.org/x/term";
            version = "v0.28.0";
            hash = "sha256-gzgGVvx6+sx1iN/2tq040OadWxRP1Kwb8mQ/cmkksmo=";
          };
          "golang.org/x/text" = fetchFromGoProxy {
            importPath = "golang.org/x/text";
            version = "v0.21.0";
            hash = "sha256-0ofHx031lkO/bffzWSX1wrNH5Cn5+nUlVA2vRJul8F4=";
          };
          "golang.org/x/tools" = fetchFromGoProxy {
            importPath = "golang.org/x/tools";
            version = "v0.29.0";
            hash = "sha256-AKHikCAGADseTsmU0gJ6xw5iRGaZAANQ+I3XLsEqGq0=";
          };
        };
      in
      stdenv.mkDerivation (finalAttrs: {
        name = "golang.org/x";

        dontUnpack = true;
        dontRewriteGoMod = true;

        env.NIX_GO_PROXY = lib.pipe srcs [
          (lib.mapAttrsToList (pname: src: "${pname}@${src.version}:${src}"))
          (lib.concatStringsSep " ")
        ];

        nativeBuildInputs = [
          hooks.configureGoProxy
          hooks.configureGoCache
          goPackages.go
        ];

        propagatedBuildInputs = [
          goPackages."github.com/google/go-cmdtest"
          goPackages."github.com/google/go-cmp"
          goPackages."github.com/google/renameio"
          goPackages."github.com/yuin/goldmark"
          goPackages."golang.org/x/sync"
          goPackages."golang.org/x/sys"
          goPackages."golang.org/x/time"
          goPackages."golang.org/x/xerrors"
        ];

        buildPhase =
          ''
            runHook preBuild

            export HOME=$(mktemp -d)
            mkdir -p "$out/nix-support"
            mkdir workspace
            pushd workspace
          ''
          + (lib.pipe srcs [
            (lib.mapAttrsToList (
              importPath: src: ''
                dirname=$(basename ${importPath})

                echo "Copying ${importPath}@${src.version} into workspace/$dirname"
                cp -R ${src}/${src.importPath}@${src.version} $dirname
                chmod -R u+w $dirname
                pushd $dirname

                echo "Rewriting $dirname/go.mod"
                rm -rf vendor
                rm -f go.sum
                for availableDeps in $NIX_GO_PROXY; do
                  # Input form is <importPath>@v<version>:<storepath>
                  local storepath="''${availableDeps#*:}"
                  local importPath="''${availableDeps%%@v*}"
                  local version="''${availableDeps##*@}"
                  version="''${version%%:*}"

                  echo "adding replace statement for ''${importPath}@''${version} to go.mod"
                  echo "replace $importPath => $importPath $version" >> go.mod
                done
                export GOSUMDB=off
                go mod tidy
                echo "go.mod after rewrite:"
                cat go.mod

                echo "Building ${importPath}/..."
                go build ./...
                popd

                cat >>"$out/nix-support/setup-hook" <<EOF
                appendToVar NIX_GO_PROXY "${importPath}@${src.version}:${src}"
                EOF
              ''
            ))
            (lib.concatStringsSep "\n")
          ])
          + ''
            runHook postBuild
          '';

        passthru = lib.mapAttrs' (
          name: src:
          (lib.nameValuePair src.name (
            stdenv.mkDerivation {
              pname = name;
              version = lib.removePrefix "v" (src.version or src.rev);
              inherit src;
              nativeBuildInputs = [
                hooks.buildGoCacheOutputSetupHook
                hooks.buildGoVendorOutputSetupHook
              ];
              buildPhase = ''
                runHook preBuild

                mkdir -p $out
                cp -r ${goPackages."_golang.org/x"}/* $out/

                runHook postBuild
              '';
              dontInstall = true;
            }
          ))
        ) srcs;
      })
    ) { };
    "golang.org/x/crypto" = callPackage ({ goPackages }: goPackages."_golang.org/x") { };
    "golang.org/x/exp" = callPackage ({ goPackages }: goPackages."_golang.org/x") { };
    "golang.org/x/mod" = callPackage ({ goPackages }: goPackages."_golang.org/x") { };
    "golang.org/x/net" = callPackage ({ goPackages }: goPackages."_golang.org/x") { };
    "golang.org/x/telemetry" = callPackage ({ goPackages }: goPackages."_golang.org/x") { };
    "golang.org/x/term" = callPackage ({ goPackages }: goPackages."_golang.org/x") { };
    "golang.org/x/text" = callPackage ({ goPackages }: goPackages."_golang.org/x") { };
    "golang.org/x/tools" = callPackage ({ goPackages }: goPackages."_golang.org/x") { };
    "golang.org/x/sync" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "golang.org/x/sync";
        version = "0.10.0";
        hash = "sha256-ZuaERAdlrkGSuH4VDsofBaDIyNuJW1KayISlCg000Mc=";
      }
    ) { };
    "golang.org/x/sys" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "golang.org/x/sys";
        version = "0.29.0";
        hash = "sha256-7XRREQevZFsUFBJqVVl6+Yo7v78Loo7iPFbtTyoLAGU=";
      }
    ) { };
    "golang.org/x/time" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "golang.org/x/time";
        version = "0.9.0";
        hash = "sha256-+0Mf+5+grLuZPIkzjeFYWXZUhTVczvSvorsBXkmzlg0=";
      }
    ) { };
    "golang.org/x/xerrors" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "golang.org/x/xerrors";
        version = "0.0.0-20190717185122-a985d3407aa7";
        hash = "sha256-aE5/9krYWY5d1sKDxEZMBlnrCBMpMwXtLqnXxK4qv5o=";
      }
    ) { };
  }
  // (
    let
      scanDir' =
        callPackage: root: prefixToAdd:
        let
          scanDir'' = scanDir' callPackage;
          dir = builtins.readDir root;
          processChild =
            name: typ:
            if typ == "regular" && name == "package.nix" then
              [ (lib.nameValuePair prefixToAdd (callPackage (root + "/${name}") { })) ]
            else if typ == "directory" && !(builtins.pathExists (root + "/.skip-tree")) then
              scanDir'' (root + "/${name}") (prefixToAdd + "${if prefixToAdd == "" then "" else "/"}${name}")
            else
              [ ];
          processChildByName = name: processChild name dir.${name};
        in
        builtins.concatMap processChildByName (builtins.attrNames dir);
      scanDir = callPackage: root: builtins.listToAttrs (scanDir' callPackage root "");
    in
    scanDir final.callPackage ./go-packages
  )
)
