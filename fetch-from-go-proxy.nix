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
    rm -rf $GOMODCACHE/cache/download/sumdb
  ''
