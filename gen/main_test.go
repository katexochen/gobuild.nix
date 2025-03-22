package main

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

const fetcherFailureExample = `warning: found empty hash, assuming 'sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
this derivation will be built:
  /nix/store/j9grm1z24xn0wk1mj2idqfly99ls3adn-goproxy-github.com-rogpeppe-go-internal-latest.drv
building '/nix/store/j9grm1z24xn0wk1mj2idqfly99ls3adn-goproxy-github.com-rogpeppe-go-internal-latest.drv' on 'ssh-ng://builder'...
copying 0 paths...
building '/nix/store/j9grm1z24xn0wk1mj2idqfly99ls3adn-goproxy-github.com-rogpeppe-go-internal-latest.drv'...
error: build of '/nix/store/j9grm1z24xn0wk1mj2idqfly99ls3adn-goproxy-github.com-rogpeppe-go-internal-latest.drv' on 'ssh-ng://builder' failed: hash mismatch in fixed-output derivation '/nix/store/j9grm1z24xn0wk1mj2idqfly99ls3adn-goproxy-github.com-rogpeppe-go-internal-latest.drv':
         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
            got:    sha256-x7deBOGzOIiNLsLfhAV3ZuSJwYifLa6NcDRjHFmnlKk=
error: builder for '/nix/store/j9grm1z24xn0wk1mj2idqfly99ls3adn-goproxy-github.com-rogpeppe-go-internal-latest.drv' failed with exit code 1`

func TestFODHashFromFetcherFailure(t *testing.T) {
	assert := assert.New(t)
	hash, err := FODHashFromFetcherFailure(fetcherFailureExample)
	assert.NoError(err)
	assert.Equal("sha256-x7deBOGzOIiNLsLfhAV3ZuSJwYifLa6NcDRjHFmnlKk=", hash)
}
