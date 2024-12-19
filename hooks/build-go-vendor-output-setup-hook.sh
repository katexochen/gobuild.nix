goVendorOutputSetupHook() {
  mkdir -p "$out/nix-support"
  cat >>"$out/nix-support/setup-hook" <<EOF
addToSearchPath NIX_GO_VENDOR "${src}/${pname}@v${version}"
EOF
}

if [ -z "${dontUseGoVendorOutputSetupHook-}" ]; then
  postPhases+=" goVendorOutputSetupHook"
fi
