{
  fetchFromGoProxy,
  goPackages,
  stdenv,
  go,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/stretchr/objx";
  version = "0.1.0";

  src = fetchFromGoProxy {
    importPath = "github.com/stretchr/objx";
    version = "v${finalAttrs.version}";
    hash = "sha256-u4F8fN13hj65GHB5GGqF4YSOQeroyDejAM/YvqMCNXc=";
  };

  postPatch = ''
    export HOME=$(pwd)
    go mod init github.com/stretchr/objx
  '';

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
    go
  ];
})
