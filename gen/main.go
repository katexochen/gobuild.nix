package main

import (
	"bytes"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"

	"golang.org/x/mod/modfile"
)

const goPkgsPath = "go-packages"

func main() {
	importPath, version, ok := strings.Cut(os.Args[1], "@")
	if !ok {
		log.Fatalf("Invalid import path format: %q. Expected 'pname@version'", os.Args[1])
	}
	// if _, err := os.Stat(path.Join(goPkgsPath, importPath)); err == nil {
	// 	return
	// }

	src, err := FetchFromGitHubFromImportpath(importPath)
	if err != nil {
		log.Fatalf("Error creating src from import path: %v", err)
	}
	src.Tag = version
	version = strings.TrimPrefix(version, "v")

	src.Hash, src.storePath, err = fetch(src)
	if err != nil {
		log.Fatalf("Error prefetching %q: %v", os.Args[1], err)
	}

	modFile, err := readMod(path.Join(src.storePath, "go.mod"))
	if err != nil {
		log.Fatalf("Error reading go.mod: %v", err)
	}

	var directRequires []string
	for _, r := range modFile.Require {
		if r.Indirect {
			continue
		}
		directRequires = append(directRequires, fmt.Sprintf("goPackages.%q", r.Mod.Path))
	}

	pkg := Pkg{
		Imports: []string{
			"fetchFromGitHub",
			"stdenv",
			"goPackages",
		},
		ImportPath: importPath,
		Version:    version,
		Source:     src,
		NativeBuildInputs: []string{
			"goPackages.hooks.makeGoDependency",
		},
		PropagatedBuildInputs: directRequires,
	}
	out, err := pkg.MarshalText()
	if err != nil {
		log.Fatalf("Error marshaling src: %v", err)
	}
	out = nixfmt(out)

	if err := os.MkdirAll(importPath, 0o755); err != nil {
		log.Fatalf("Error creating go-packages directory: %v", err)
	}
	f, err := os.OpenFile(filepath.Join(goPkgsPath, importPath, "package.nix"), os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		log.Fatalf("Error creating go-packages file: %v", err)
	}
	defer f.Close()
	if _, err := f.Write(out); err != nil {
		log.Fatalf("Error writing go-packages file: %v", err)
	}
}

type Pkg struct {
	Imports               []string
	ImportPath            string
	Version               string
	Source                FetchFromGitHub
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
	b.WriteString(fmt.Sprintf("\nsrc = %s;\n\n", src))
	b.WriteString("nativeBuildInputs = [\n")
	for _, nbi := range p.NativeBuildInputs {
		b.WriteString(fmt.Sprintf("%s\n", nbi))
	}
	b.WriteString("];\n\n")
	if len(p.PropagatedBuildInputs) > 0 {
		b.WriteString("propagatedBuildInputs = [\n")
		for _, pbi := range p.PropagatedBuildInputs {
			b.WriteString(fmt.Sprintf("%s\n", pbi))
		}
		b.WriteString("];\n\n")
	}
	b.WriteString("})")
	return []byte(b.String()), nil
}

type FetchFromGitHub struct {
	Owner string
	Repo  string
	Rev   string
	Tag   string
	Hash  string

	storePath string
}

func FetchFromGitHubFromImportpath(importPath string) (FetchFromGitHub, error) {
	parts := strings.Split(importPath, "/")
	if len(parts) != 3 {
		log.Fatalf("Invalid import path: %q. Expected 'github.com/owner/repo'", importPath)
	}
	return FetchFromGitHub{
		Owner: parts[1],
		Repo:  parts[2],
	}, nil
}

func (f FetchFromGitHub) MarshalText() ([]byte, error) {
	b := strings.Builder{}
	b.WriteString("fetchFromGitHub {\n")
	b.WriteString(fmt.Sprintf("owner = %q;\n", f.Owner))
	b.WriteString(fmt.Sprintf("repo = %q;\n", f.Repo))
	if f.Tag != "" {
		b.WriteString("tag = \"v${finalAttrs.version}\";\n")
	} else {
		b.WriteString(fmt.Sprintf("rev = %q;\n", f.Rev))
	}
	b.WriteString(fmt.Sprintf("hash = %q;\n", f.Hash))
	b.WriteString("}")
	return []byte(b.String()), nil
}

func (f FetchFromGitHub) URL() string {
	rev := f.Tag
	if rev == "" {
		rev = f.Rev
	}
	return fmt.Sprintf("https://github.com/%s/%s/archive/%s.tar.gz", f.Owner, f.Repo, rev)
}

type URLer interface {
	URL() string
}

func fetch(urler URLer) (hash, storePath string, retErr error) {
	cmd := exec.Command("nix-prefetch-url", "--print-path", "--unpack", urler.URL())
	output, err := cmd.Output()
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		return "", "", fmt.Errorf("executing nix-prefetch-url: %s", exitErr.Stderr)
	} else if err != nil {
		return "", "", err
	}

	hash, storePath, ok := strings.Cut(string(output), "\n")
	if !ok {
		return "", "", fmt.Errorf("splitting nix-prefetch-url output: %s", string(output))
	}
	storePath = strings.TrimSpace(storePath)

	cmd = exec.Command("nix-hash", "--sri", "--type", "sha256", storePath)
	sriHash, err := cmd.Output()
	if errors.As(err, &exitErr) {
		return "", "", fmt.Errorf("executing nix-hash: %s", exitErr.Stderr)
	} else if err != nil {
		return "", "", err
	}

	return strings.TrimSpace(string(sriHash)), storePath, nil
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
