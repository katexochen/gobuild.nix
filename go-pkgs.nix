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
            hash = "sha256-VYv7SMxdSrTDGZRzvBTg80j/0Vr5dgZxL6EJG6fCVrg=";
          };
          "golang.org/x/exp" = fetchFromGoProxy {
            importPath = "golang.org/x/exp";
            version = "v0.0.0-20250106191152-7588d65b2ba8";
            hash = "sha256-fv32GYy8Y7yrPoqwPtrH1LpH33vezmfzvzSNsnwam18=";
          };
          "golang.org/x/mod" = fetchFromGoProxy {
            importPath = "golang.org/x/mod";
            version = "v0.22.0";
            hash = "sha256-8M6tZF3YvI77rvZZK66udF/zsMfRs2NUhvLcGxE1/j4=";
          };
          "golang.org/x/net" = fetchFromGoProxy {
            importPath = "golang.org/x/net";
            version = "v0.34.0";
            hash = "sha256-zyXIkUJZV1Y25KTsjG+sGeWvV/TeqWycTMzfqYOESS0=";
          };
          "golang.org/x/telemetry" = fetchFromGoProxy {
            importPath = "golang.org/x/telemetry";
            version = "v0.0.0-20250117155846-04cd7bae618c";
            hash = "sha256-KuhoHiV8U098SD124Py6U70QJPanIUhVBWaiLJ+RPrw=";
          };
          "golang.org/x/term" = fetchFromGoProxy {
            importPath = "golang.org/x/term";
            version = "v0.28.0";
            hash = "sha256-Ri1Qrlq0OYnqmfsH7UoFK+iblEOwnM4WKQYJzAIcavA=";
          };
          "golang.org/x/text" = fetchFromGoProxy {
            importPath = "golang.org/x/text";
            version = "v0.21.0";
            hash = "sha256-1YQLLyVOeEHausyIS4x654nCr3auzSt40ZruL8Hf9HI=";
          };
          "golang.org/x/tools" = fetchFromGoProxy {
            importPath = "golang.org/x/tools";
            version = "v0.29.0";
            hash = "sha256-jlxlV8/yr/cXyVC0x3lo8eYwqbfRO+29oiT3+7mJbKE=";
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
        hash = "sha256-FYXUV8yjQrLrFYM6Hwv/OvyNuKJxQt4iso4DcBUmnQ8=";
      }
    ) { };
    "golang.org/x/sys" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "golang.org/x/sys";
        version = "0.29.0";
        hash = "sha256-1Af536qFQC1kXToTnI/BAud1wpyIeU95BhqpsThcYTo=";
      }
    ) { };
    "golang.org/x/time" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "golang.org/x/time";
        version = "0.9.0";
        hash = "sha256-Mw7yeAUs/HtfpUA4rHb9OCat9RJGjSYgPGI1W1d15gY=";
      }
    ) { };
    "golang.org/x/xerrors" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "golang.org/x/xerrors";
        version = "0.0.0-20190717185122-a985d3407aa7";
        hash = "sha256-001Bye5gcBBNZf3Pifkp9f4tfJ7UQaunY53yRHxjMxg=";
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
