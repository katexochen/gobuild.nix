package main

import (
	"bytes"
	"context"
	_ "embed"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/spf13/cobra"
	"golang.org/x/mod/modfile"
)

const goPkgsPath = "go-packages"

//go:embed eval-fetch-go-proxy.nix
var evalFetchGoProxyNix []byte

func main() {
	cmd := newRootCmd()
	if err := cmd.ExecuteContext(context.Background()); err != nil {
		os.Exit(1)
	}
}

func runRoot(cmd *cobra.Command, args []string) error {
	importPath, version, ok := strings.Cut(args[0], "@")
	if !ok {
		return fmt.Errorf("invalid import path format: %q. Expected 'pname@version'", args[0])
	}

	override, err := cmd.Flags().GetBool("override")
	if err != nil {
		return err
	}

	return Package(importPath, version, override)
}

func newRootCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "gen <go-import-path>",
		Short: "gen",
		RunE:  runRoot,
	}
	cmd.Flags().Bool("override", false, "override existing files")
	return cmd
}

func Package(importPath, version string, override bool) error {
	if _, err := os.Stat(path.Join(goPkgsPath, importPath)); err == nil && !override {
		// Package already exists, and we don't want to update existing code.
		log.Printf("Package %s already exists, not updating it (pass --override to update existing packages)\n", importPath)
		return nil
	}

	log.Printf("Packaging %s@%s\n", importPath, version)

	version = strings.TrimPrefix(version, "v")
	src := FetchFromGoProxy{
		ImportPath: importPath,
		Version:    version,
	}

	src, err := prefetchGoProxy(src)
	if err != nil {
		return fmt.Errorf("fetching '%s@%s': %w", importPath, version, err)
	}

	pkg := Pkg{
		Imports: []string{
			"fetchFromGoProxy",
			"goPackages",
			"stdenv",
		},
		ImportPath: importPath,
		Version:    version,
		Source:     src,
		NativeBuildInputs: []string{
			"goPackages.hooks.makeGoDependency",
		},
	}

	modFile, err := readMod(src.storePath)
	var noGoModErr NoGoModError
	if errors.As(err, &noGoModErr) {
		pkg.PostPatch = []string{
			"export HOME=$(pwd)",
			fmt.Sprintf("go mod init %s", importPath),
		}
		pkg.NativeBuildInputs = append(pkg.NativeBuildInputs, "go")
		pkg.Imports = append(pkg.Imports, "go")
	} else if err != nil {
		return fmt.Errorf("reading go.mod: %w", err)
	} else {
		for _, r := range modFile.Require {
			if r.Indirect {
				continue
			}
			pkg.PropagatedBuildInputs = append(pkg.PropagatedBuildInputs, fmt.Sprintf("goPackages.%q", r.Mod.Path))
		}
	}

	out, err := pkg.MarshalText()
	if err != nil {
		return fmt.Errorf("marshaling src: %w", err)
	}
	out = nixfmt(out)

	if err := os.MkdirAll(filepath.Join(goPkgsPath, importPath), 0o755); err != nil {
		return fmt.Errorf("creating go-packages directory: %w", err)
	}
	outputPath := filepath.Join(goPkgsPath, importPath, "package.nix")
	f, err := os.OpenFile(outputPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		return fmt.Errorf("creating go-packages file: %w", err)
	}
	defer f.Close()
	if _, err := f.Write(out); err != nil {
		return fmt.Errorf("writing go-packages file: %w", err)
	}

	log.Printf("Generated %s", outputPath)

	// If there's no modfile we can't recurse into the dependencies.
	if modFile == nil {
		return nil
	}
	var deps []*modfile.Require
	for _, r := range modFile.Require {
		if r.Indirect {
			continue
		}
		deps = append(deps, r)
	}

	for _, dep := range deps {
		if strings.HasPrefix(dep.Mod.Path, "golang.org/x") {
			continue
		}
		if err := Package(dep.Mod.Path, dep.Mod.Version, override); err != nil {
			return fmt.Errorf("packaging dependency %q: %w", dep.Mod.Path, err)
		}
	}

	return nil
}

type Pkg struct {
	Imports               []string
	ImportPath            string
	Version               string
	Source                FetchFromGoProxy
	PostPatch             []string
	NativeBuildInputs     []string
	PropagatedBuildInputs []string
}

func (p Pkg) MarshalText() ([]byte, error) {
	b := strings.Builder{}
	b.WriteString("{\n")
	for _, imp := range p.Imports {
		b.WriteString(fmt.Sprintf("%s,\n", imp))
	}
	b.WriteString("}:\n\n")
	b.WriteString("stdenv.mkDerivation (finalAttrs: {\n")
	b.WriteString(fmt.Sprintf("pname = %q;\n", p.ImportPath))
	b.WriteString(fmt.Sprintf("version = %q;\n", p.Version))
	src, err := p.Source.MarshalText()
	if err != nil {
		return nil, err
	}
	b.WriteString(fmt.Sprintf("\nsrc = %s;\n", src))
	if len(p.PostPatch) > 0 {
		b.WriteString("\npostPatch = ''\n")
		for _, pf := range p.PostPatch {
			b.WriteString(fmt.Sprintf("%s\n", pf))
		}
		b.WriteString("'';\n")
	}
	b.WriteString("\nnativeBuildInputs = [\n")
	for _, nbi := range p.NativeBuildInputs {
		b.WriteString(fmt.Sprintf("%s\n", nbi))
	}
	b.WriteString("];\n")
	if len(p.PropagatedBuildInputs) > 0 {
		b.WriteString("\npropagatedBuildInputs = [\n")
		for _, pbi := range p.PropagatedBuildInputs {
			b.WriteString(fmt.Sprintf("%s\n", pbi))
		}
		b.WriteString("];\n")
	}
	b.WriteString("})")
	return []byte(b.String()), nil
}

type FetchFromGoProxy struct {
	ImportPath string
	Version    string
	Hash       string

	storePath string
}

func (f FetchFromGoProxy) MarshalText() ([]byte, error) {
	b := strings.Builder{}
	b.WriteString("fetchFromGoProxy {\n")
	b.WriteString(fmt.Sprintf("importPath = %q;\n", f.ImportPath))
	b.WriteString("version = \"v${finalAttrs.version}\";\n")
	b.WriteString(fmt.Sprintf("hash = %q;\n", f.Hash))
	b.WriteString("}")
	return []byte(b.String()), nil
}

func prefetchGoProxy(fetcher FetchFromGoProxy) (FetchFromGoProxy, error) {
	fetcherFile, err := os.CreateTemp("", "fetchFromGoProxy.*.nix")
	if err != nil {
		return FetchFromGoProxy{}, err
	}
	defer fetcherFile.Close()
	defer os.Remove(fetcherFile.Name())

	if _, err := fetcherFile.Write(evalFetchGoProxyNix); err != nil {
		return FetchFromGoProxy{}, err
	}

	// Invoke nix-build to get the hash mismatch error
	args := []string{}
	args = append(args, fetcherFile.Name())
	args = append(args, "--no-build-output") // Little hardening so we don't match on some build output.
	args = append(args, "--argstr", "importPath", fetcher.ImportPath)
	args = append(args, "--argstr", "version", fmt.Sprintf("v%s", fetcher.Version))
	cmd := exec.Command("nix-build", args...)
	out, err := cmd.CombinedOutput()
	if err == nil {
		return FetchFromGoProxy{}, fmt.Errorf("expected error, got success")
	}

	hash, err := FODHashFromFetcherFailure(string(out))
	if err != nil {
		return FetchFromGoProxy{}, fmt.Errorf("parsing fetcher failure: %w", err)
	}
	fetcher.Hash = strings.TrimSpace(hash)

	// Invoke nix-build again to get the store path
	args = []string{}
	args = append(args, fetcherFile.Name())
	args = append(args, "--no-build-output")
	args = append(args, "--no-out-link")
	args = append(args, "--argstr", "importPath", fetcher.ImportPath)
	args = append(args, "--argstr", "version", fmt.Sprintf("v%s", fetcher.Version))
	args = append(args, "--argstr", "hash", fetcher.Hash)
	cmd = exec.Command("nix-build", args...)
	out, err = cmd.Output()
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		return FetchFromGoProxy{}, fmt.Errorf("fetching store path: %s", exitErr.Stderr)
	} else if err != nil {
		return FetchFromGoProxy{}, fmt.Errorf("fetching store path: %w", err)
	}
	fetcher.storePath = strings.TrimSpace(string(out))
	log.Printf("Fetched %s", fetcher.storePath)

	return fetcher, nil
}

func nixfmt(b []byte) []byte {
	cmd := exec.Command("nixfmt")
	cmd.Stdin = bytes.NewBuffer(b)
	out, err := cmd.Output()
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		log.Fatalf("Error formatting nix: %s", exitErr.Stderr)
	} else if err != nil {
		log.Fatalf("Error formatting nix: %v", err)
	}
	return out
}

type NoGoModError struct {
	path string
}

func (e NoGoModError) Error() string {
	return fmt.Sprintf("no go.mod found in %q", e.path)
}

func readMod(storePath string) (*modfile.File, error) {
	dirEntries, err := os.ReadDir(storePath)
	if err != nil {
		return nil, fmt.Errorf("reading store path %q: %w", storePath, err)
	}
	if len(dirEntries) != 2 || !dirEntries[0].IsDir() || !dirEntries[1].IsDir() {
		return nil, fmt.Errorf("expected two directories in src fetched with fetchFromGoProxy, got %d", len(dirEntries))
	}
	var modPath string
	if dirEntries[0].Name() == "cache" {
		modPath = dirEntries[1].Name()
	} else {
		if dirEntries[1].Name() != "cache" {
			return nil, fmt.Errorf("expected one directory to be named 'cache', got %q, %q", dirEntries[0].Name(), dirEntries[1].Name())
		}
		modPath = dirEntries[0].Name()
	}
	for {
		dirEntries, err := os.ReadDir(filepath.Join(storePath, modPath))
		if err != nil {
			return nil, fmt.Errorf("reading %q: %w", modPath, err)
		}
		if len(dirEntries) != 1 {
			break
		}
		if !dirEntries[0].IsDir() {
			break
		}
		modPath = filepath.Join(modPath, dirEntries[0].Name())
	}
	modPath = filepath.Join(storePath, modPath, "go.mod")
	if _, err := os.Stat(modPath); errors.Is(err, os.ErrNotExist) {
		return nil, NoGoModError{path: storePath}
	} else if err != nil {
		return nil, fmt.Errorf("reading go.mod: %w", err)
	}

	modBytes, err := os.ReadFile(modPath)
	if err != nil {
		return nil, fmt.Errorf("reading go.mod from %q: %w", modPath, err)
	}

	mod, err := modfile.Parse(modPath, modBytes, nil)
	if err != nil {
		return nil, err
	}
	return mod, nil
}

var specifiedGotReg = regexp.MustCompile(`specified: +(.*)\n\s+got: +(.*)`)

func FODHashFromFetcherFailure(failure string) (string, error) {
	// Ensure there is only one match
	matches := specifiedGotReg.FindAllStringSubmatch(failure, -1)
	if len(matches) != 1 {
		return "", fmt.Errorf("expected one match, got %d", len(matches))
	}

	// Ensure there are two groups
	if len(matches[0]) != 3 {
		return "", fmt.Errorf("expected two groups, got %d", len(matches[0]))
	}

	if matches[0][1] != "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" {
		return "", fmt.Errorf("expected first group to be 'sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', got %q", matches[0][1])
	}

	if len(matches[0][2]) != 51 {
		return "", fmt.Errorf("expected second group to be 51 characters long, got %d: %q", len(matches[0][2]), matches[0][2])
	}

	return matches[0][2], nil
}
