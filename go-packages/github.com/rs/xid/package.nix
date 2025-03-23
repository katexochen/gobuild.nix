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
    hash = "sha256-tXRd1GoK9FjgW3thc+k77LvE1NasNJn3592WHiVFwqY=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];
})
