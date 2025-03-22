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
    hash = "sha256-7rEkS7sjSn996wNqlgomyTVHq3MyJGtorOk46v9sBAI=";
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
