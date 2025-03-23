{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "gopkg.in/yaml.v3";
  version = "3.0.1";

  src = fetchFromGoProxy {
    importPath = "gopkg.in/yaml.v3";
    version = "v${finalAttrs.version}";
    hash = "sha256-zF9M4+1jcuEeaIgmjW9blhgi+ajJZInVjNgSwvhAuGk=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];

  propagatedBuildInputs = [
    goPackages."gopkg.in/check.v1"
  ];
})
