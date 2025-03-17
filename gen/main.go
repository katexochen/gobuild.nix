package main

import (
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path"
	"strings"
)

const goPkgsPath = "go-packages"

func main() {
	importPath, version, ok := strings.Cut(os.Args[1], "@")
	if !ok {
		log.Fatalf("Invalid import path format: %q. Expected 'pname@version'", os.Args[1])
	}
	if _, err := os.Stat(path.Join(goPkgsPath, importPath)); err == nil {
		return
	}

	hash, storePath, err := fetch(importPath, version)
	if err != nil {
		log.Fatalf("Error prefetching %q: %v", os.Args[1], err)
	}

	pkg := Pkg{
		ImportPath: importPath,
		Version:    version,
		Source:     Source{StorePath: storePath, Hash: hash},
	}
	log.Printf("Pkg: %s", pkg)
}

type Pkg struct {
	ImportPath string
	Version    string
	Source     Source
}

type Source struct {
	StorePath string
	Hash      string
}

func fetch(importPath, version string) (hash, storePath string, retErr error) {
	cmd := exec.Command("nix-prefetch-url", "--print-path", "--unpack", fmt.Sprintf("https://%s/archive/refs/tags/%s.tar.gz", importPath, version))
	output, err := cmd.Output()
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		return "", "", fmt.Errorf("executing nix-prefetch-url: %s", exitErr.Stderr)
	}
	if err != nil {
		return "", "", err
	}

	hash, storePath, ok := strings.Cut(string(output), "\n")
	if !ok {
		return "", "", fmt.Errorf("splitting nix-prefetch-url output:", string(output))
	}

	return hash, storePath, nil
}
