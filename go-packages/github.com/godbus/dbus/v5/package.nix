{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/godbus/dbus/v5";
  version = "5.0.4";

  src = fetchFromGoProxy {
    importPath = "github.com/godbus/dbus/v5";
    version = "v${finalAttrs.version}";
    hash = "sha256-WCXESHn3xuPBXrsgtgF9AaqT/xstE10HfpXv4UlEsdI=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];
})
