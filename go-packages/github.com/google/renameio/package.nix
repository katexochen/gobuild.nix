{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/google/renameio";
  version = "0.1.0";

  src = fetchFromGoProxy {
    importPath = "github.com/google/renameio";
    version = "v${finalAttrs.version}";
    hash = "sha256-TZheOkAf/HX8UIKYd4DweZypKKZOagk98F99v9oZWZ8=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];
})
