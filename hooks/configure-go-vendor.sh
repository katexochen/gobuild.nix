echo "Sourcing configure-go-vendor-hook"

goConfigureVendor() {
  echo "Executing goConfigureVendor"

  if [ -z "${NIX_GO_VENDOR:-}" ]; then
    echo "NIX_GO_VENDOR is not set, not configuring Go vendor"
    return
  fi
  echo "NIX_GO_VENDOR: ${NIX_GO_VENDOR:-}"

  # Cleanup vendor, we want to write our own vendor dir.
  rm -rf vendor
  # Cleanup go.sum, sums won't match with the rewritten go.mod.
  rm -f go.sum
  # Keep backup of go.mod for debugging.
  mv go.mod go.mod.old
  # Use module directive from old go.mod.
  grep -E '^module [^ ]+$' go.mod.old > go.mod
  # Add go directive to go.mod.
  echo "go @go_version@" >> go.mod

  export HOME=$(mktemp -d)

  for dep in ${NIX_GO_VENDOR}; do
    # Input form is <pname>@v<version>:<storepath>
    local storepath="${dep#*:}"
    local pname="${dep%%@v*}"
    local version="${dep##*@}"
    version="${version%%:*}"

    echo "adding ${pname}@${version} to vendor, storepath: ${storepath}"

    # pname is a path, the last element in this path should be our symlink.
    # Create the other directories from pname.
    mkdir -p "vendor/${pname%/*}"
    cp -r "${storepath}" vendor/${pname} # TODO: use ln -s, special case golang.org/x

    # Add the dependency to go.mod.
    echo "adding ${pname}@${version} to go.mod"
    echo "require ${pname} ${version}" >> go.mod
  done

  echo "go.mod after rewrite:"
  cat go.mod

  echo "Finished executing goConfigureVendor"
}

if [ -z "${dontUseGoConfigureVendor-}" ]; then
  echo "Using goConfigureVendor"
  appendToVar preConfigurePhases goConfigureVendor
fi
