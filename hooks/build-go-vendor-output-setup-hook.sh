goVendorOutputSetupHook() {
  mkdir -p "$out/nix-support"
  cat >>"$out/nix-support/setup-hook" <<EOF
appendToVar NIX_GO_VENDOR "${pname}@v${version}:${src}"
EOF
}

if [ -z "${dontUseGoVendorOutputSetupHook-}" ]; then
  postPhases+=" goVendorOutputSetupHook"
fi
