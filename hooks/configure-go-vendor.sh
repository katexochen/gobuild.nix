echo "Sourcing configure-go-vendor-hook"

goConfigureVendor() {
  echo "Executing goConfigureVendor"

  echo "NIX_GO_VENDOR: ${NIX_GO_VENDOR}"
  if [ -z "${NIX_GO_VENDOR}" ]; then
    echo "NIX_GO_VENDOR is not set, not configuring Go vendor"
    return
  fi

  while read -r dep; do
    # Input form is /nix/store/<storepath>/<pname>@v<version>
    local storepath=${dep%/*/*/*}
    local withoutNixStore="${dep#/nix/store/}"
    local withoutStorepath="${withoutNixStore#*/}"
    local pname="${withoutStorepath%%@v*}"
    local version="${withoutStorepath##*@v}"
    goDirective=$(grep -E '^go [0-9]+[.][0-9]+([.][0-9]+)?$' "${storepath}/go.mod" || true)

    echo "adding ${pname}@${version} to vendor"

    mkdir -p "vendor/${pname%/*}"
    ln -s "${storepath}" vendor/${pname}

  done < <(tr ':' '\n' <<< "${NIX_GO_VENDOR}")

  echo "Finished executing goConfigureVendor"
}

if [ -z "${dontUseGoConfigureVendor-}" ]; then
  echo "Using goConfigureVendor"
  appendToVar preConfigurePhases goConfigureVendor
fi
