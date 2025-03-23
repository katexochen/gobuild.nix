{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/google/go-cmdtest";
  version = "0.3.0";

  src = fetchFromGoProxy {
    importPath = "github.com/google/go-cmdtest";
    version = "v${finalAttrs.version}";
    hash = "sha256-T5jbV6yGrj1VR62M2gQFztEVN2kbZpet84RxwbH9Zqo=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];

  propagatedBuildInputs = [
    goPackages."github.com/google/go-cmp"
    goPackages."github.com/google/renameio"
  ];
})
