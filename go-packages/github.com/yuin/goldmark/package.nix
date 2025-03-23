{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/yuin/goldmark";
  version = "1.7.8";

  src = fetchFromGoProxy {
    importPath = "github.com/yuin/goldmark";
    version = "v${finalAttrs.version}";
    hash = "sha256-V0Fp4FnBMTSP9tRfmZiOrlTW0QOCPFXkjGlpw+11uy8=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];
})
