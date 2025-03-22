{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/rs/xid";
  version = "1.5.0";

  src = fetchFromGoProxy {
    importPath = "github.com/rs/xid";
    version = "v${finalAttrs.version}";
    hash = "sha256-cX1W9lpqWiiECniQZYSbA38CYkmkPXrNq5yWdeVkw4E=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];
})
