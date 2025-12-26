// Analyze local Go workspaces & packages to achieve per _package_ incrementality instead of just per _module_
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"golang.org/x/mod/modfile"
)

const WORK_FILE = "go.work"

type goListPackageModule struct {
	Path string
}

type goListPackage struct {
	Module goListPackageModule
	ImportPath string
	Dir        string
	Imports    []string
}

func listPackages(directory string, listPackages ...string) ([]*goListPackage, error) {
	var packages []*goListPackage

	args := append([]string{"list", "-json"}, listPackages...)
	cmd := exec.Command("go", args...)
	cmd.Dir = directory
	stdout, err := cmd.Output()
	if err != nil {
		if exiterr, ok := err.(*exec.ExitError); ok {
			return nil, fmt.Errorf("failed to run 'go list --json: %s\n%s", exiterr, exiterr.Stderr)
		} else {
			return nil, fmt.Errorf("failed to run 'go list --json': %s", err)
		}
	}

	dec := json.NewDecoder(bytes.NewReader(stdout))
	for {
		var pkg *goListPackage
		err := dec.Decode(&pkg)
		if err == io.EOF {
			break
		} else {

			pkg.Dir = strings.TrimPrefix(pkg.Dir, directory) // We want the project local directory
			packages = append(packages, pkg)
		}
	}

	return packages, nil
}

func listWorkspace(directory string) ([]*goListPackage, error) {
	workPath := filepath.Join(directory, WORK_FILE)

	// Check if it's a workspace & recurse into
	if _, err := os.Stat(workPath); err == nil {
		var workPackages []*goListPackage

		contents, err := os.ReadFile(workPath)
		if err != nil {
			return nil, fmt.Errorf("error reading go.work: %w", err)
		}

		work, err := modfile.ParseWork(workPath, contents, nil)
		if err != nil {
			return nil, fmt.Errorf("error parsing go.work: %w", err)
		}

		for _, use := range work.Use {
			pkgPath := filepath.Join(directory, use.Path)

			packages, err := listPackages(pkgPath, pkgPath + "/...")
			if err != nil {
				return nil, fmt.Errorf("error analyzing %s: %w", pkgPath, err)
			}

			workPackages = append(workPackages, packages...)
		}

		return workPackages, nil
	}

	// Not a workspace, treat as a plain package
	return listPackages(directory, "./...")
}
