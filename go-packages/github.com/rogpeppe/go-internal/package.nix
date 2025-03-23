{
  stdenv,
  goPackages,
  fetchFromGoProxy,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/rogpeppe/go-internal";
  version = "1.13.1";

  src = fetchFromGoProxy {
    importPath = "github.com/rogpeppe/go-internal";
    version = "v${finalAttrs.version}";
    hash = "sha256-lalIHhGvG9tARO4IycqAQmpAlc/uhdnn7NNt3pCfV5g=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];

  propagatedBuildInputs = [
    goPackages."golang.org/x/mod"
    goPackages."golang.org/x/sys"
    goPackages."golang.org/x/tools"
  ];
})
