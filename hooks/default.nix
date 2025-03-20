{
  callPackage,
  makeSetupHook,
  go,
  gobuild-nix-cacher,
  lib,
}:

let
  goExe = lib.getExe go;
in

{
  makeGoDependency = callPackage (
    { hooks }:
    makeSetupHook {
      name = "make-go-dependency-hook";
      propagatedBuildInputs = [
        hooks.configureGoProxy
        hooks.configureGoCache
        hooks.buildGo
        hooks.buildGoCacheOutputSetupHook
        hooks.buildGoProxyOutputSetupHook
      ];
    } ./make-go-dependency.sh
  ) { };

  makeGoBinary = callPackage (
    { hooks }:
    makeSetupHook {
      name = "make-go-binary-hook";
      propagatedBuildInputs = [
        hooks.configureGoProxy
        hooks.configureGoCache
        hooks.buildGo
        hooks.installGo
      ];
    } ./make-go-binary.sh
  ) { };

  configureGoCache = callPackage (
    { }:
    makeSetupHook {
      name = "configure-go-cache-hook";
      substitutions = {
        cacher = lib.getExe gobuild-nix-cacher;
        go = goExe;
      };
    } ./configure-go-cache.sh
  ) { };

  configureGoVendor = callPackage (
    { }:
    makeSetupHook {
      name = "configure-go-vendor-hook";
      substitutions = {
        go = goExe;
        go_version = go.version;
      };
    } ./configure-go-vendor.sh
  ) { };

  configureGoProxy = callPackage (
    { }:
    makeSetupHook {
      name = "configure-go-proxy-hook";
      substitutions = {
        go = goExe;
        go_version = go.version;
      };
    } ./configure-go-proxy.sh
  ) { };

  buildGo = callPackage (
    { }:
    makeSetupHook {
      name = "build-go-hook";
      substitutions = {
        go = goExe;
      };
    } ./build-go.sh
  ) { };

  installGo = callPackage (
    { }:
    makeSetupHook {
      name = "install-go-hook";
      substitutions = {
        go = goExe;
      };
    } ./install-go.sh
  ) { };

  buildGoCacheOutputSetupHook = callPackage (
    { }:
    makeSetupHook {
      name = "build-go-cache-output-setup-hook";
      substitutions = {
        go = goExe;
      };
    } ./build-go-cache-output-setup-hook.sh
  ) { };

  buildGoVendorOutputSetupHook = callPackage (
    { }:
    makeSetupHook {
      name = "build-go-vendor-output-setup-hook";
      substitutions = {
        go = goExe;
      };
    } ./build-go-vendor-output-setup-hook.sh
  ) { };

  buildGoProxyOutputSetupHook = callPackage (
    { }:
    makeSetupHook {
      name = "build-go-proxy-output-setup-hook";
      substitutions = {
        go = goExe;
      };
    } ./build-go-proxy-output-setup-hook.sh
  ) { };
}
