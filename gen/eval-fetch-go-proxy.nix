{
  nixpkgs ? <nixpkgs>,
  pkgs ? import nixpkgs { },

  hash ? "",
  importPath,
  version,
}:

let
  fetchFromGoProxy = pkgs.callPackage (
    { runCommandNoCC, go }:

    {
      importPath,
      version,
      hash,
    }:

    runCommandNoCC "goproxy-${importPath}-${version}"
      {
        buildInputs = [ go ];
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = hash;
        passthru = { inherit importPath version; };
      }
      ''
        export HOME=$TMPDIR
        export GOMODCACHE=$out
        export GOPROXY=https://proxy.golang.org
        go mod download ${importPath}@${version}
        # Remove the sumdb shards downloaded by go mod download, they are not reproducible.
        rm -r $GOMODCACHE/cache/download/sumdb
      ''
  ) { };
in

fetchFromGoProxy {
  inherit importPath version hash;
}
