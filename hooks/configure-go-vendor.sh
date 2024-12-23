echo "Sourcing configure-go-vendor-hook"

goConfigureVendor() {
  echo "Executing goConfigureVendor"

  echo "NIX_GO_VENDOR: ${NIX_GO_VENDOR}"
  if [ -z "${NIX_GO_VENDOR}" ]; then
    echo "NIX_GO_VENDOR is not set, skipping goConfigureVendor"
    return
  fi

  export HOME=$TMPDIR
  export GOSUMDB=off
  echo GOPROXY=$GOPROXY

  while read -r dep; do
    # Input form is /nix/store/<storepath>/<pname>@v<version>
    local storepath=${dep%/*/*/*}
    local withoutNixStore="${dep#/nix/store/}"
    local withoutStorepath="${withoutNixStore#*/}"
    local pname="${withoutStorepath%%@v*}"
    local version="${withoutStorepath##*@v}"
    @go@ mod edit -replace=${pname}=${pname}@v${version}
  done < <(tr ':' '\n' <<< "${NIX_GO_VENDOR}")

  cat go.mod

  @go@ mod tidy

  echo "Finished executing goConfigureVendor"
}

if [ -z "${dontUseGoConfigureVendor-}" ]; then
  echo "Using goConfigureVendor"
  appendToVar preConfigurePhases goConfigureVendor
fi
