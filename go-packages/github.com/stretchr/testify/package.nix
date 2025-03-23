{
  fetchFromGoProxy,
  goPackages,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/stretchr/testify";
  version = "1.7.0";

  src = fetchFromGoProxy {
    importPath = "github.com/stretchr/testify";
    version = "v${finalAttrs.version}";
    hash = "sha256-Z9NZuxRRC1ImSi+Cb7k8myi6IjobH+1I+szrSGQvUts=";
  };

  nativeBuildInputs = [
    goPackages.hooks.makeGoDependency
  ];

  propagatedBuildInputs = [
    goPackages."github.com/davecgh/go-spew"
    goPackages."github.com/pmezard/go-difflib"
    goPackages."github.com/stretchr/objx"
    goPackages."gopkg.in/yaml.v3"
  ];
})
