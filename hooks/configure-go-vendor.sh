echo "Sourcing configure-go-vendor-hook"

goConfigureVendor() {
  echo "Executing goConfigureVendor"

  echo "NIX_GO_VENDOR: ${NIX_GO_VENDOR}"
  if [ -z "${NIX_GO_VENDOR}" ]; then
    echo "NIX_GO_VENDOR is not set, not configuring Go vendor"
    return
  fi

  for dep in ${NIX_GO_VENDOR}; do
    # Input form is /nix/store/<storepath>/<pname>@v<version>
    local storepath=${dep%/*/*/*}
    local withoutNixStore="${dep#/nix/store/}"
    local withoutStorepath="${withoutNixStore#*/}"
    local pname="${withoutStorepath%%@v*}"
    local version="${withoutStorepath##*@v}"

    echo "adding ${pname}@${version} to vendor"

    mkdir -p "vendor/${pname%/*}"
    ln -s "${storepath}" vendor/${pname}
  done

  echo "Finished executing goConfigureVendor"
}

if [ -z "${dontUseGoConfigureVendor-}" ]; then
  echo "Using goConfigureVendor"
  appendToVar preConfigurePhases goConfigureVendor
fi
