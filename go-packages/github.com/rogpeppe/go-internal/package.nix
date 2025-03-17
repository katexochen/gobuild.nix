{ mkGoModule, goPackages }:

mkGoModule {
  pname = "github.com/rogpeppe/go-internal";
  version = "1.13.1";
  hash = "sha256-fD4n3XVDNHL7hfUXK9qi31LpBVzWnRK/7LNc3BmPtnU=";
  buildInputs = [
    goPackages."golang.org/x/mod"
    goPackages."golang.org/x/sys"
    goPackages."golang.org/x/tools"
  ];
}
