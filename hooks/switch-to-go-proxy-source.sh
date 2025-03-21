echo "Sourcing switch-to-go-proxy-source-hook"

goSwitchToGoProxySource() {
  echo "Executing switchToGoProxySourceHook"

    # If we're consuming a source from a Go proxy,
    # the source should have exactly two directories:
    # 'cache' and something with the domain name of the import path.
    if [[ "$(ls -1 | wc -l)" -ne 2 ]]; then
      echo "Source has more than two directories, not a Go proxy source, skipping switchToGoProxySourceHook"
      return
    fi
    if [ ! -d cache ]; then
      echo "No 'cache' directory found, not a Go proxy source, skipping switchToGoProxySourceHook"
      return
    fi
    cd "$(ls -1 | grep -v cache)"
    while [[ ! -f "go.mod" ]]; do
        if [[ "$(ls -1 | wc -l)" -ne 1 ]]; then
            ls -1
            echo "Warning: No 'go.mod' file found in switchToGoProxySourceHook"
            return
        fi
        cd "$(ls)" || exit 1
    done
    echo "Found 'go.mod' file in $(pwd)"

  echo "Finished executing switchToGoProxySourceHook"
}

echo "Using switchToGoProxySourceHook"
appendToVar prePatchHooks goSwitchToGoProxySource
