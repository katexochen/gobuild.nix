package main

import (
	"fmt"
	"os"
	"path/filepath"
	"errors"

	"github.com/BurntSushi/toml"
)

const CONFIG_FILE = "gobuild-nix.toml"

type configFile struct {
	Package bool `toml:"package"`
}

func ReadConfig(directory string) (*configFile, error) {
	configPath := filepath.Join(directory, CONFIG_FILE)

	// Return default config if no file provided
	if _, err := os.Stat(configPath); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return &configFile{}, nil
		} else {
			return nil, err
		}
	}

	contents, err := os.ReadFile(configPath)
	if err != nil {
		return nil, fmt.Errorf("error reading previous lockfile: %w", err)
	}

	config := &configFile{}
	if err = toml.Unmarshal(contents, config); err != nil {
		return nil, err
	}

	return config, nil
}
