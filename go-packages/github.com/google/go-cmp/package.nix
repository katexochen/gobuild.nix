{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/google/go-cmp";
  version = "0.6.0";

  src = fetchFromGoProxy {
    importPath = "github.com/google/go-cmp";
    version = "v${finalAttrs.version}";
    hash = "sha256-cTZvg6svBSFLdmNinaT4HPL9cfPeeDSPItHIpK8sijo=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];
})
