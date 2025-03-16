{
  pkgs ?
    let
      flakeLock = builtins.fromJSON (builtins.readFile ./flake.lock);
      inherit (flakeLock.nodes.nixpkgs) locked;
    in
    import (builtins.fetchTree locked) { },
}:

let

  # Go package set containing build cache output & hooks
  goPackages = pkgs.callPackages ./go-pkgs.nix { };

in
{
  inherit goPackages;

  fsnotify =
    let
      base = goPackages."github.com/fsnotify/fsnotify";
    in
    pkgs.stdenv.mkDerivation {
      pname = "fsnotify";
      inherit (base) version src;

      buildInputs = [
        # base
        goPackages."golang.org/x/sys"
      ];

      nativeBuildInputs =
        let
          inherit (goPackages) hooks;
        in
        [
          hooks.configureGoVendor
          hooks.configureGoCache
          hooks.buildGo
          hooks.installGo
        ];
    };

  simple-package = pkgs.stdenv.mkDerivation (finalAttrs: {
    name = "simple-package";

    src = ./fixtures/simple-package;

    nativeBuildInputs =
      let
        inherit (goPackages) hooks;
      in
      [
        hooks.configureGoVendor
        hooks.configureGoCache
        hooks.buildGo
        hooks.installGo
      ];

    buildInputs = [
      goPackages."github.com/alecthomas/kong"
    ];
  });

  keep-sorted = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "keep-sorted";
    version = "0.6.0";

    src = pkgs.fetchFromGitHub {
      owner = "google";
      repo = "keep-sorted";
      tag = "v${finalAttrs.version}";
      hash = "sha256-ROvj7w8YMq6+ntx0SWi+HfN4sO6d7RjKWwlb/9gfz8w=";
    };

    postPatch = ''
      substituteInPlace main.go \
        --replace-fail 'readVersion())' '"v${finalAttrs.version}")'
    '';

    nativeBuildInputs =
      let
        inherit (goPackages) hooks;
      in
      [
        hooks.configureGoVendor
        hooks.configureGoCache
        hooks.buildGo
        hooks.installGo
      ];

    buildInputs = [
      goPackages."github.com/Workiva/go-datastructures"
      goPackages."github.com/google/go-cmp"
      goPackages."github.com/mattn/go-isatty"
      goPackages."github.com/rs/zerolog"
      goPackages."github.com/spf13/pflag"
      goPackages."gopkg.in/yaml.v3"
    ];

    nativeInstallCheckInputs = [ pkgs.versionCheckHook ];

    doInstallCheck = true;
  });
}
