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
    hash = "sha256-N51PRBsfZw0A9z/FfwvsiBI8ICbfaX2qQmREeHFkF+g=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];
})
