{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/rs/zerolog";
  version = "1.33.0";

  src = fetchFromGoProxy {
    importPath = "github.com/rs/zerolog";
    version = "v${finalAttrs.version}";
    hash = "sha256-lkfdZeFcCq8XRBPiNRxezCTGCgTYeEAHYeeWBu2Mxzg=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];

  propagatedBuildInputs = [
    goPackages."github.com/coreos/go-systemd/v22"
    goPackages."github.com/mattn/go-colorable"
    goPackages."github.com/pkg/errors"
    goPackages."github.com/rs/xid"
  ];
})
