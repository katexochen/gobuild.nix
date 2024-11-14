{
  callPackage,
  makeSetupHook,
  go,
  lib,
}:

{
  buildGo = callPackage (
    { }:
    makeSetupHook {
      name = "build-go-hook";
      substitutions = {
        go = lib.getExe go;
      };
    } ./build-go.sh
  ) { };
  
  installGo = callPackage (
    { }:
    makeSetupHook {
      name = "install-go-hook";
      substitutions = {
        go = lib.getExe go;
      };
    } ./install-go.sh
  ) { };
  
  buildGoCacheOutputSetupHook = callPackage (
    { }:
    makeSetupHook {
      name = "build-go-cache-output-setup-hook";
      substitutions = {
        go = lib.getExe go;
      };
    } ./build-go-cache-output-setup-hook.sh
  ) { };
}
