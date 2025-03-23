{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/spf13/pflag";
  version = "1.0.5";

  src = fetchFromGoProxy {
    importPath = "github.com/spf13/pflag";
    version = "v${finalAttrs.version}";
    hash = "sha256-vzx7HgiiFz0X8MiOhdcU/ZIp+AfNaXaGD/rzPCNsODk=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];
})
