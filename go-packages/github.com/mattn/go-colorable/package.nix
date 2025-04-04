{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/mattn/go-colorable";
  version = "0.1.13";

  src = fetchFromGoProxy {
    importPath = "github.com/mattn/go-colorable";
    version = "v${finalAttrs.version}";
    hash = "sha256-4RS7X0kzpgZaHxyr7YvpXyx73r+t2MG9obIZvtRBdJY=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];

  propagatedBuildInputs = [
    goPackages."github.com/mattn/go-isatty"
  ];
})
