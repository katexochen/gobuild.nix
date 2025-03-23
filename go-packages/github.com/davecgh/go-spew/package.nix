{
  fetchFromGoProxy,
  goPackages,
  stdenv,
  go,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/davecgh/go-spew";
  version = "1.1.0";

  src = fetchFromGoProxy {
    importPath = "github.com/davecgh/go-spew";
    version = "v${finalAttrs.version}";
    hash = "sha256-UAtPoPLYeRSOeXNVyLF6CSjQAyv8tVEGIgpskeW6KGk=";
  };

  postPatch = ''
    export HOME=$(pwd)
    go mod init github.com/davecgh/go-spew
  '';

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
    go
  ];
})
