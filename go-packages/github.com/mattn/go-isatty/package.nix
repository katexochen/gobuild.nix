{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/mattn/go-isatty";
  version = "0.0.16";

  src = fetchFromGoProxy {
    importPath = "github.com/mattn/go-isatty";
    version = "v${finalAttrs.version}";
    hash = "sha256-Nk9cLLLJpiCKPEV2Yw2QZF6Bn/dGJ6l0tD03c4qQlAY=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];

  propagatedBuildInputs = [
    goPackages."golang.org/x/sys"
  ];
})
