{
  fetchFromGoProxy,
  goPackages,
  stdenv,
  go,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/pkg/errors";
  version = "0.9.1";

  src = fetchFromGoProxy {
    importPath = "github.com/pkg/errors";
    version = "v${finalAttrs.version}";
    hash = "sha256-xqD/59ziFv9tCp+W3kjldaoXK3dEMZbFW9B9t6j0zOM=";
  };

  postPatch = ''
    export HOME=$(pwd)
    go mod init github.com/pkg/errors
  '';

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
    go
  ];
})
