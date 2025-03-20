goProxyOutputSetupHook() {
  mkdir -p "$out/nix-support"
  cat >>"$out/nix-support/setup-hook" <<EOF
appendToVar NIX_GO_PROXY "${pname}@v${version}:${src}"
EOF
}

if [ -z "${dontUseGoProxyOutputSetupHook-}" ]; then
  postPhases+=" goProxyOutputSetupHook"
fi
