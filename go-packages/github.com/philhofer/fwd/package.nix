{
  fetchFromGoProxy,
  goPackages,
  stdenv,
  go,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/philhofer/fwd";
  version = "1.1.1";

  src = fetchFromGoProxy {
    importPath = "github.com/philhofer/fwd";
    version = "v${finalAttrs.version}";
    hash = "sha256-CUUAU9XCsYX7r+snxDdj78nZTu/AqOPw7p4O0Ny0khg=";
  };

  postPatch = ''
    export HOME=$(pwd)
    go mod init github.com/philhofer/fwd
  '';

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
    go
  ];
})
