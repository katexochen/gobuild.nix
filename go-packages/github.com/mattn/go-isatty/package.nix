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
    hash = "sha256-UUc2nOQebFX2fusKvsOGBBpLvcB44p20Iq8v9O26jxY=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];

  propagatedBuildInputs = [
    goPackages."golang.org/x/sys"
  ];
})
