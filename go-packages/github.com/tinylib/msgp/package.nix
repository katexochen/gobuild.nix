{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/tinylib/msgp";
  version = "1.1.5";

  src = fetchFromGoProxy {
    importPath = "github.com/tinylib/msgp";
    version = "v${finalAttrs.version}";
    hash = "sha256-ze5k4L/8CpBy0mzeX0kIPtU7BEq9rYiEVN91zcqXZT8=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];

  propagatedBuildInputs = [
    goPackages."github.com/philhofer/fwd"
    goPackages."github.com/ttacon/chalk"
    goPackages."golang.org/x/tools"
  ];
})
