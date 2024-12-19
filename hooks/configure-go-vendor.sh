echo "Sourcing configure-go-vendor-hook"

goConfigureVendor() {
  echo "Executing goConfigureVendor"

echo "NIX_GO_VENDOR: ${NIX_GO_VENDOR}"
  while read -r dep; do
    # Input form is /nix/store/<storepath>/<pname>@v<version>
    withoutNixStore="${dep#/nix/store/}"
    withoutStorepath="${withoutNixStore#*/}"
    pname="${withoutStorepath%%@v*}"
    version="${withoutStorepath##*@v}"
    goDirective=$(grep -E '^go [0-9]+[.][0-9]+([.][0-9]+)?$' "${dep}/go.mod" || true)

    echo "adding ${pname}@${version} to vendor"

    mkdir -p "vendor/${pname%/*}"
    ln -s "${dep}" vendor/${pname}

    cat >> vendor/modules.txt << EOF
# ${pname} v${version}
## explicit; ${goDirective}
${pname}
EOF
  done < <(tr ':' '\n' <<< "${NIX_GO_VENDOR}")

  echo "Finished executing goConfigureVendor"
}

if [ -z "${dontUseGoConfigureVendor-}" ]; then
  echo "Using goConfigureVendor"
  appendToVar preConfigurePhases goConfigureVendor
fi
