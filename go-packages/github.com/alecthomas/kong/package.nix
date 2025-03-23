{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/alecthomas/kong";
  version = "1.4.0";

  src = fetchFromGoProxy {
    importPath = "github.com/alecthomas/kong";
    version = "v${finalAttrs.version}";
    hash = "sha256-xOYhjQFvdqsecF//ztyUoRQVyVbSfubbQbMFfKUI2kw=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];

  propagatedBuildInputs = [
    goPackages."github.com/alecthomas/assert/v2"
    goPackages."github.com/alecthomas/repr"
  ];
})
