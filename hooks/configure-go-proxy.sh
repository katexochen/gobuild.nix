echo "Sourcing configure-go-proxy-hook"

rewriteGoMod() {
  # Cleanup vendor, we can't reuse it.
  rm -rf vendor
  # Cleanup go.sum, sums won't match with the rewritten go.mod.
  rm -f go.sum
  # Keep backup of go.mod for debugging.
  mv go.mod go.mod.old
  # Use module directive from old go.mod.
  grep -E '^module [^ ]+$' go.mod.old > go.mod
  # Add go directive to go.mod.
  echo "go @go_version@" >> go.mod

   for dep in ${NIX_GO_PROXY}; do
    # Input form is <pname>@v<version>:<storepath>
    local pname="${dep%%@v*}"
    local version="${dep##*@}"
    version="${version%%:*}"
    echo "adding ${pname}@${version} to go.mod"
    echo "require ${pname} ${version}" >> go.mod
    # Replace will also affect transitive requires.
    echo "replace ${pname} => ${pname} ${version}" >> go.mod
  done

  @go@ mod tidy
  echo "go.mod after rewrite:"
  cat go.mod
}

goConfigureProxy() {
  echo "Executing goConfigureVendor"

  if [ -z "${NIX_GO_PROXY:-}" ]; then
    echo "NIX_GO_PROXY is not set, not configuring Go vendor"
    return
  fi
  echo "NIX_GO_PROXY: ${NIX_GO_PROXY:-}"

  export HOME=$(mktemp -d)
  proxyDir=$(mktemp -d)

  for dep in ${NIX_GO_PROXY}; do
    # Input form is <pname>@v<version>:<storepath>
    local storepath="${dep#*:}"
    local pname="${dep%%@v*}"

    # Upper case package names are escaped as '!<lowercase>' in the proxy protocol,
    # so we need to convert to get the right path in the proxy directory.
    ppath=${pname}
    ppath=$(echo "$ppath" | sed 's/\([A-Z]\)/!\L\1/g' | sed 's/!!/!/g')

    # Add the dependency to the GOPROXY dir
    mkdir -p "${proxyDir}/${ppath}"
    ln -s \
      "${storepath}/cache/download/${ppath}/@v" \
      "${proxyDir}/${ppath}/@v"
  done

  export GOPROXY="file://${proxyDir}"
  export GOSUMDB="off"

  if [[ -z "${dontRewriteGoMod-}" ]]; then
    rewriteGoMod
  fi

  echo "Finished executing goConfigureProxy"
}

if [ -z "${dontUseGoConfigureProxy-}" ]; then
  echo "Using goConfigureProxy"
  appendToVar preConfigurePhases goConfigureProxy
fi
