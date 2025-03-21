{
  stdenv,
  goPackages,
  fetchFromGoProxy,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/rogpeppe/go-internal";
  version = "1.13.1";

  src = fetchFromGoProxy {
    pname = "github.com/rogpeppe/go-internal";
    version = "v${finalAttrs.version}";
    hash = "sha256-U4L7DSs/h0GEH/m9jfLHNzSNUlYdZigiH5e57+o5hJI=";
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
