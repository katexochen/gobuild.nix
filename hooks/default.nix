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
      };
    } ./configure-go-vendor.sh
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
}
