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
    hash = "sha256-a4vMOmbJ2LhK0s/9fL5GVa8yR3bHVRrs1ayAgSZA6o0=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];

  propagatedBuildInputs = [
    goPackages."github.com/mattn/go-isatty"
  ];
})
