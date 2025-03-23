{
  fetchFromGoProxy,
  goPackages,
  stdenv,
  go,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/ttacon/chalk";
  version = "0.0.0-20160626202418-22c06c80ed31";

  src = fetchFromGoProxy {
    importPath = "github.com/ttacon/chalk";
    version = "v${finalAttrs.version}";
    hash = "sha256-i4vb0nbwoVsNpABhZ+HgyXGL4TOq/DA3DmVLTu0N0hU=";
  };

  postPatch = ''
    export HOME=$(pwd)
    go mod init github.com/ttacon/chalk
  '';

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
    go
  ];
})
