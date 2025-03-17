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

	output, err := fetch(importPath, version)
	if err != nil {
		log.Fatalf("Error prefetching %q: %v", os.Args[1], err)
	}
	log.Printf("Output %s", output)
}

func fetch(importPath, version string) (string, error) {
	cmd := exec.Command("nix-prefetch-url", "--print-path", "--unpack", fmt.Sprintf("https://%s/archive/refs/tags/%s.tar.gz", importPath, version))
	output, err := cmd.Output()
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		return "", fmt.Errorf("executing nix-prefetch-url: %s", exitErr.Stderr)
	}
	if err != nil {
		return "", err
	}
	return string(output), nil
}
