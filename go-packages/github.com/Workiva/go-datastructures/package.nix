{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/Workiva/go-datastructures";
  version = "1.1.5";

  src = fetchFromGoProxy {
    importPath = "github.com/Workiva/go-datastructures";
    version = "v${finalAttrs.version}";
    hash = "sha256-Q4N1ILeneHvvJ3vA13UI5wTq/Yx0xm6pK+BNJkVU36g=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];

  propagatedBuildInputs = [
    goPackages."github.com/stretchr/testify"
    goPackages."github.com/tinylib/msgp"
  ];
})
