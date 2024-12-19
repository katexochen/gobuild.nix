goVendorOutputSetupHook() {
  mkdir -p "$out/nix-support"
  cat >>"$out/nix-support/setup-hook" <<EOF
appendToVar NIX_GO_VENDOR "${src}/${pname}@v${version}"
EOF
}

if [ -z "${dontUseGoVendorOutputSetupHook-}" ]; then
  postPhases+=" goVendorOutputSetupHook"
fi
