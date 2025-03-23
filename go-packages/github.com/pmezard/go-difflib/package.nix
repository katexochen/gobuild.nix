{
  fetchFromGoProxy,
  goPackages,
  stdenv,
  go,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/pmezard/go-difflib";
  version = "1.0.0";

  src = fetchFromGoProxy {
    importPath = "github.com/pmezard/go-difflib";
    version = "v${finalAttrs.version}";
    hash = "sha256-eYv1P6X3jHFwxZb3TsavUnXZqvJwjDuQYFRs5r7m2ZU=";
  };

  postPatch = ''
    export HOME=$(pwd)
    go mod init github.com/pmezard/go-difflib
  '';

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
    go
  ];
})
