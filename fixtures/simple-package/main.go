package main

import (
		"github.com/alecthomas/kong"
)

var cli struct {
		Debug bool `help:"Enable debug mode."`
}

type Context struct {
  Debug bool
}

func main() {
		ctx := kong.Parse(&cli)
		err := ctx.Run(&Context{Debug: cli.Debug})
		ctx.FatalIfErrorf(err)
}
