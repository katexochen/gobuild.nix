package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
	"golang.org/x/mod/modfile"
)

const goPkgsPath = "go-packages"

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

	src, err := prefetchGoProxySimple(src)
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

	modFile, err := readMod(path.Join(src.storePath, "go.mod"))
	if errors.Is(err, os.ErrNotExist) {
		pkg.PostPatch = []string{
			"export HOME=$(pwd)",
			fmt.Sprintf("go mod init %s", importPath),
		}
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

func prefetchGoProxySimple(fod FetchFromGoProxy) (FetchFromGoProxy, error) {
	tmpDir, err := os.MkdirTemp("", "fetchFromGoProxy.*")
	if err != nil {
		return FetchFromGoProxy{}, err
	}
	fod.storePath = fmt.Sprintf("%s/%s@v%s", tmpDir, fod.ImportPath, fod.Version)
	tmpHomeDir, err := os.MkdirTemp("", "home.*")
	if err != nil {
		return FetchFromGoProxy{}, err
	}
	defer os.RemoveAll(tmpHomeDir)

	// go mod download the package
	cmd := exec.Command("go", "mod", "download", fmt.Sprintf("%s@v%s", fod.ImportPath, fod.Version))
	cmd.Dir = tmpDir
	cmd.Env = append(cmd.Env, fmt.Sprintf("GOMODCACHE=%s", tmpDir))
	cmd.Env = append(cmd.Env, fmt.Sprintf("HOME=%s", tmpHomeDir))
	var exitErr *exec.ExitError
	if out, err := cmd.CombinedOutput(); errors.As(err, &exitErr) {
		return FetchFromGoProxy{}, fmt.Errorf("go mod download: %s, %v", out, err)
	} else if err != nil {
		return FetchFromGoProxy{}, fmt.Errorf("go mod download: %v", err)
	}

	// Do same cleanup as fetchFromGoProxy
	if err := os.RemoveAll(filepath.Join(tmpDir, "cache/download/sumdb")); err != nil {
		return FetchFromGoProxy{}, err
	}

	// Calculate the hash
	cmd = exec.Command("nix-hash", "--type", "sha256", tmpDir)
	hash, err := cmd.Output()
	if errors.As(err, &exitErr) {
		return FetchFromGoProxy{}, fmt.Errorf("nix-hash: %s, %v", exitErr.Stderr, err)
	} else if err != nil {
		return FetchFromGoProxy{}, fmt.Errorf("nix-hash: %v", err)
	}
	hash = bytes.TrimSpace(hash)

	// Convert the hash to SRI
	cmd = exec.Command("nix-hash", "--type", "sha256", "--to-sri", string(hash))
	sri, err := cmd.Output()
	if errors.As(err, &exitErr) {
		return FetchFromGoProxy{}, fmt.Errorf("nix-hash: %s", exitErr.Stderr)
	} else if err != nil {
		return FetchFromGoProxy{}, fmt.Errorf("nix-hash: %v", err)
	}

	fod.Hash = strings.TrimSpace(string(sri))
	return fod, nil
}

func prefetchGoProxy(fod FetchFromGoProxy) (FetchFromGoProxy, error) {
	// Create a temporary file
	fodFile, err := os.CreateTemp("", "fetchFromGoProxy.*.nix")
	if err != nil {
		return FetchFromGoProxy{}, err
	}
	defer fodFile.Close()
	defer os.Remove(fodFile.Name())

	// Marshal the FetchFromGoProxy to nix expression
	fodBytes, err := fod.MarshalText()
	if err != nil {
		return FetchFromGoProxy{}, err
	}

	// Write the nix expression to the file
	if _, err := fodFile.Write(fodBytes); err != nil {
		return FetchFromGoProxy{}, err
	}

	// Create a second temporary "entrypoint" file
	entrypointFile, err := os.CreateTemp("", "entrypoint.*.nix")
	if err != nil {
		return FetchFromGoProxy{}, err
	}
	defer entrypointFile.Close()
	defer os.Remove(entrypointFile.Name())

	// The entry point should take some pinned flake reference form the local flake that
	// contains the fetchFromGoProxy function.
	// TODO

	return fod, nil
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

func readMod(modpath string) (*modfile.File, error) {
	modBytes, err := os.ReadFile(modpath)
	if err != nil {
		return nil, err
	}

	mod, err := modfile.Parse("go.mod", modBytes, nil)
	if err != nil {
		return nil, err
	}
	return mod, nil
}
