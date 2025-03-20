{
  stdenv,
  fetchFromGitHub,
  goPackages,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "github.com/rogpeppe/go-internal";
  version = "1.13.1";

  src = fetchFromGitHub {
    owner = "rogpeppe";
    repo = "go-internal";
    tag = "v${finalAttrs.version}";
    hash = "sha256-fD4n3XVDNHL7hfUXK9qi31LpBVzWnRK/7LNc3BmPtnU=";
  };

  nativeBuildInputs = [ goPackages.hooks.makeGoDependency ];

  propagatedBuildInputs = [
    goPackages."golang.org/x/mod"
    goPackages."golang.org/x/sys"
    goPackages."golang.org/x/tools"
  ];
})
