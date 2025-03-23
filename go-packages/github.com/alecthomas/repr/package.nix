{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/alecthomas/repr";
  version = "0.4.0";

  src = fetchFromGoProxy {
    importPath = "github.com/alecthomas/repr";
    version = "v${finalAttrs.version}";
    hash = "sha256-3zlG7RbVw7pKtDhxwf7PVIn+NuF48vZaSHi8w5kgaZ4=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];
})
