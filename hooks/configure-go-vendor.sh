echo "Sourcing configure-go-vendor-hook"

goConfigureVendor() {
  echo "Executing goConfigureVendor"

  echo "NIX_GO_VENDOR: ${NIX_GO_VENDOR}"
  if [ -z "${NIX_GO_VENDOR}" ]; then
    echo "NIX_GO_VENDOR is not set, not configuring Go vendor"
    return
  fi

  for dep in ${NIX_GO_VENDOR}; do
    # Input form is <pname>@v<version>:<storepath>
    local storepath="${dep#*:}"
    local pname="${dep%%@v*}"
    local version="${dep##*@}"
    version="${version%%:*}"

    echo "adding ${pname}@${version} to vendor, storepath: ${storepath}"

    mkdir -p "vendor/${pname%/*}"
    ln -s "${storepath}" vendor/${pname}
  done

  echo "Updating go directive in go.mod to @go_version@"
  sed -E -i 's/^go [0-9]+\.[0-9]+(\.[0-9]+)?/go @go_version@/' go.mod

  echo "Finished executing goConfigureVendor"
}

if [ -z "${dontUseGoConfigureVendor-}" ]; then
  echo "Using goConfigureVendor"
  appendToVar preConfigurePhases goConfigureVendor
fi
