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
            inherit pname hash;
            version = "v${version}";
          };
          nativeBuildInputs = [
            hooks.makeGoDependency
          ] ++ nativeBuildInputs;
          propagatedBuildInputs = buildInputs;
          dontInstall = true;

          postPatch = ''
            ppath=${pname}@v${version}
            ppath=$(echo "$ppath" | sed 's/\([A-Z]\)/!\L\1/g' | sed 's/!!/!/g')
            pushd "$ppath"
          '';
        }
        // args'
      )
    ) { };

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
          passthru = { inherit pname version; };
        }
        ''
          export HOME=$TMPDIR
          export GOMODCACHE=$out
          export GOPROXY=https://proxy.golang.org
          go mod download ${pname}@${version}
        ''
    ) { };

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
            pname = "golang.org/x/crypto";
            version = "v0.32.0";
            hash = "sha256-VYv7SMxdSrTDGZRzvBTg80j/0Vr5dgZxL6EJG6fCVrg=";
          };
          "golang.org/x/exp" = fetchFromGoProxy {
            pname = "golang.org/x/exp";
            version = "v0.0.0-20250106191152-7588d65b2ba8";
            hash = "sha256-fv32GYy8Y7yrPoqwPtrH1LpH33vezmfzvzSNsnwam18=";
          };
          "golang.org/x/mod" = fetchFromGoProxy {
            pname = "golang.org/x/mod";
            version = "v0.22.0";
            hash = "sha256-8M6tZF3YvI77rvZZK66udF/zsMfRs2NUhvLcGxE1/j4=";
          };
          "golang.org/x/net" = fetchFromGoProxy {
            pname = "golang.org/x/net";
            version = "v0.34.0";
            hash = "sha256-zyXIkUJZV1Y25KTsjG+sGeWvV/TeqWycTMzfqYOESS0=";
          };
          "golang.org/x/telemetry" = fetchFromGoProxy {
            pname = "golang.org/x/telemetry";
            version = "v0.0.0-20250117155846-04cd7bae618c";
            hash = "sha256-KuhoHiV8U098SD124Py6U70QJPanIUhVBWaiLJ+RPrw=";
          };
          "golang.org/x/term" = fetchFromGoProxy {
            pname = "golang.org/x/term";
            version = "v0.28.0";
            hash = "sha256-Ri1Qrlq0OYnqmfsH7UoFK+iblEOwnM4WKQYJzAIcavA=";
          };
          "golang.org/x/text" = fetchFromGoProxy {
            pname = "golang.org/x/text";
            version = "v0.21.0";
            hash = "sha256-1YQLLyVOeEHausyIS4x654nCr3auzSt40ZruL8Hf9HI=";
          };
          "golang.org/x/tools" = fetchFromGoProxy {
            pname = "golang.org/x/tools";
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
              pname: src: ''
                dirname=$(basename ${pname})

                echo "Copying ${pname}@${src.version} into workspace/$dirname"
                cp -R ${src}/${src.pname}@${src.version} $dirname
                chmod -R u+w $dirname
                pushd $dirname

                echo "Rewriting $dirname/go.mod"
                rm -rf vendor
                rm -f go.sum
                for availableDeps in $NIX_GO_PROXY; do
                  # Input form is <pname>@v<version>:<storepath>
                  local storepath="''${availableDeps#*:}"
                  local pname="''${availableDeps%%@v*}"
                  local version="''${availableDeps##*@}"
                  version="''${version%%:*}"

                  echo "adding replace statement for ''${pname}@''${version} to go.mod"
                  echo "replace $pname => $pname $version" >> go.mod
                done
                export GOSUMDB=off
                go mod tidy
                echo "go.mod after rewrite:"
                cat go.mod

                echo "Building ${pname}/..."
                go build ./...
                popd

                cat >>"$out/nix-support/setup-hook" <<EOF
                appendToVar NIX_GO_PROXY "${pname}@${src.version}:${src}"
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

    "github.com/alecthomas/kong" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/alecthomas/kong";
        version = "1.4.0";
        hash = "sha256-7LoimcJfyBbSuKsV6Ojw9dZUCSLI/rbu2C6JkjaDQrw=";
        buildInputs = [
          goPackages."github.com/alecthomas/assert/v2"
          goPackages."github.com/alecthomas/repr"
        ];
      }
    ) { };
    "github.com/alecthomas/repr" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/alecthomas/repr";
        version = "0.4.0";
        hash = "sha256-rg9KH5Y19L1meD7S5SG0web2NK4xO4NViIp71CUOd1U=";
      }
    ) { };
    "github.com/alecthomas/assert/v2" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/alecthomas/assert/v2";
        version = "2.11.0";
        hash = "sha256-SJL1FIiAVGMOTVeepuP83ACHuOXtv3cbOXxFIXhZcOo=";
        buildInputs = [
          goPackages."github.com/alecthomas/repr"
          goPackages."github.com/hexops/gotextdiff"
        ];
      }
    ) { };
    "github.com/hexops/gotextdiff" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/hexops/gotextdiff";
        version = "1.0.3";
        hash = "sha256-CXlSF7KiqJC8eWK7n3qqRZfIE4e7+lLY9Za8x51acGA=";
      }
    ) { };
    "github.com/fsnotify/fsnotify" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/fsnotify/fsnotify";
        version = "1.8.0";
        hash = "sha256-Yn2UBgqvxe/yZKkZcqA9d1ykJn3230CmHvv/NfvppHo=";
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
        hash = "sha256-dj3A+ReK024i9bY3yqg7LIo9KMRx9/f9vSee/AKumAI=";
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
        hash = "sha256-FKtKHpIVmdv4sLthkKAAPjduFl4UAnDcjQUjx4Zn2og=";
      }
    ) { };
    "github.com/spf13/pflag" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/spf13/pflag";
        version = "1.0.5";
        hash = "sha256-JAMURPbK5pQ61d3m9QE6FGf+XpwdzT0LvZItojubD2I=";
      }
    ) { };
    "github.com/pkg/errors" = callPackage (
      { mkGoModule, go }:
      mkGoModule rec {
        pname = "github.com/pkg/errors";
        version = "0.9.1";
        hash = "sha256-tBev5M7C4bEWqik7s7iAuR9k2Hct/pr8x4AbfFQUDEs=";
        nativeBuildInputs = [
          go
        ];
        postPatch = ''
          export HOME=$(mktemp -d)
          pushd ${pname}@v${version}
          go mod init github.com/pkg/errors
        '';
      }
    ) { };
    "github.com/mattn/go-isatty" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/mattn/go-isatty";
        version = "0.0.20";
        hash = "sha256-33Q5mUDM+rWmh7maqdXFCOSq/UZTGTvRWbcezjhh1pk=";
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
        hash = "sha256-yN+uZSpyCGbYX/bFLkupwEzENd6rAcPhzJs6UpHjIpo=";
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
        hash = "sha256-mi49ehvpmwsYmf/Q4o8YDeW819Kc7Xtnl5ZMNzJKROo=";
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
        hash = "sha256-RJoJHIOTemyJruLQWALAGh3Q7eskbowdtIoAKIktGgA=";
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
        hash = "sha256-McFUWx7i9BfqK/usVDMjHffk1FzD5JrC682aqn7iCvQ=";
      }
    ) { };
    "github.com/Workiva/go-datastructures" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/Workiva/go-datastructures";
        version = "1.1.5";
        hash = "sha256-ByUpvCaYzR0symTo3VwHja611RolIcg658wnXkwiaow=";
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
        hash = "sha256-PKRKqmdG9GOUsCqpmUwfyA1ZitIXffpp1Bi4850HoWE=";
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
        hash = "sha256-CvoFUCSlDqVRe7UhkRCzNb8hkK0MZEZazkNFF25PRlw=";
      }
    ) { };
    "github.com/yuin/goldmark" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/yuin/goldmark";
        version = "1.7.8";
        hash = "sha256-KFr+Uy4bwbl0iQGiS4Ugk7HWXQNPIgt63+FuLtBqZMk=";
      }
    ) { };
    "github.com/google/go-cmdtest" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/google/go-cmdtest";
        version = "0.3.0";
        hash = "sha256-y1y+WX9JAP+jb2Fq0coiN+I/D0kSdm3mx92Yz2jCS7g=";
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
        hash = "sha256-rLyPj/LwGwHNA22mD4BCQCsXUImlFhS57c/urhCGS8A=";
      }
    ) { };
    "github.com/stretchr/testify" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/stretchr/testify";
        version = "1.10.0";
        hash = "sha256-H0tGQrgyCFlEIAmKXiGe+FE4lCviTmS0uVRMLZGv2Ts=";
        buildInputs = [
          goPackages."github.com/davecgh/go-spew"
          goPackages."github.com/pmezard/go-difflib"
          goPackages."github.com/stretchr/objx"
          goPackages."gopkg.in/yaml.v3"
        ];
      }
    ) { };
    "github.com/davecgh/go-spew" = callPackage (
      { mkGoModule }:
      mkGoModule rec {
        pname = "github.com/davecgh/go-spew";
        version = "1.1.1";
        hash = "sha256-vXsaiAdWkniANW1oZs+8HSohzsrIvOzMjW4mZ1ujlOE=";
        nativeBuildInputs = [ go ];
        # no go.mod file
        postPatch = ''
          export HOME=$(mktemp -d)
          pushd ${pname}@v${version}
          go mod init github.com/davecgh/go-spew
        '';
      }
    ) { };
    "github.com/pmezard/go-difflib" = callPackage (
      { mkGoModule }:
      mkGoModule rec {
        pname = "github.com/pmezard/go-difflib";
        version = "1.0.0";
        hash = "sha256-aI8R8DMtKiGoUjg4E40pddmWLAQx1UpEk6b+eF8++Bw=";
        nativeBuildInputs = [ go ];
        # no go.mod file
        postPatch = ''
          export HOME=$(mktemp -d)
          pushd ${pname}@v${version}
          go mod init github.com/pmezard/go-difflib
        '';
      }
    ) { };
    "github.com/stretchr/objx" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/stretchr/objx";
        version = "0.5.2";
        hash = "sha256-t9Qmp7CsRMmZM0a+/OZHkrxqvxKdcP6vuVJT3HuBKkE=";
        buildInputs = [
          # goPackages."github.com/stretchr/testify" # circular dependency
        ];
      }
    ) { };
    "gopkg.in/yaml.v3" = callPackage (
      {
        mkGoModule,
        goPackages,
      }:
      mkGoModule {
        pname = "gopkg.in/yaml.v3";
        version = "3.0.1";
        hash = "sha256-+SbWxVjEOYP6Gj4bsTDvb7op6ckowCsIQBLWlcMbc7s=";
        buildInputs = [
          goPackages."gopkg.in/check.v1"
        ];
      }
    ) { };
    "gopkg.in/check.v1" = callPackage (
      {
        mkGoModule,
        goPackages,
      }:
      mkGoModule {
        pname = "gopkg.in/check.v1";
        version = "1.0.0-20201130134442-10cb98267c6c";
        hash = "sha256-wMYqwM7tB5qlEPBwysccGrggEy+Aq7kJmXQzHKNlGYs=";
        buildInputs = [
          goPackages."github.com/kr/pretty"
        ];
      }
    ) { };
    "github.com/kr/pretty" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/kr/pretty";
        version = "0.3.1";
        hash = "sha256-dV1DuSQGY4RlXJKwdkmiOwK7CqCEBc1LwR8EeyJPlxo=";
        buildInputs = [
          goPackages."github.com/kr/text"
          goPackages."github.com/rogpeppe/go-internal"
        ];
      }
    ) { };
    "github.com/kr/text" = callPackage (
      { mkGoModule, goPackages }:
      mkGoModule {
        pname = "github.com/kr/text";
        version = "0.2.0";
        hash = "sha256-8QJ+QQwMigZNVMeyw8Pvt/IkFeY7P1EuHfCFYENFgiY=";
        buildInputs = [
          goPackages."github.com/creack/pty"
        ];
      }
    ) { };
    "github.com/creack/pty" = callPackage (
      { mkGoModule }:
      mkGoModule {
        pname = "github.com/creack/pty";
        version = "1.1.24";
        hash = "sha256-oF7q5QQ5FLD9Wh8Dl+Gal6AoohdfFLKqNrjUGk2gv80=";
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
