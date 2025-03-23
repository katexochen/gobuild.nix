{
  fetchFromGoProxy,
  goPackages,
  stdenv,
  go,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "gopkg.in/check.v1";
  version = "0.0.0-20161208181325-20d25e280405";

  src = fetchFromGoProxy {
    importPath = "gopkg.in/check.v1";
    version = "v${finalAttrs.version}";
    hash = "sha256-hgJ5paxFEyvv+P35UJVWqWqmwIU8kJEiEanEYxJ+DBc=";
  };

  postPatch = ''
    export HOME=$(pwd)
    go mod init gopkg.in/check.v1
  '';

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
    go
  ];
})
