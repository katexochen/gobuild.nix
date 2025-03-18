package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log"
	"net/url"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"

	"github.com/katexochen/gobuild.nix/gen/pkgs/github"
	"github.com/katexochen/gobuild.nix/gen/pkgs/gomod"
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

func Package(importPath string, versionStr string, override bool) error {
	log.Printf("Packaging %s@%s\n", importPath, versionStr)

	version, err := gomod.ParseGoModVersion(versionStr)
	if err != nil {
		return err
	}

	if _, err := os.Stat(path.Join(goPkgsPath, importPath)); err == nil && !override {
		// Package already exists, and we don't want to update existing code.
		log.Printf("Package %s already exists, not updating it (pass --override to update existing packages)\n", importPath)
		return nil
	}

	meta, err := gomod.FetchGoImportMeta(importPath)
	if err != nil {
		return fmt.Errorf("fetching go mod meta data: %w", err)
	}

	src, err := FetchFromGitHubFromImportPath(meta.RepoURL)
	if err != nil {
		return fmt.Errorf("creating src from import path: %w", err)
	}
	if version.IsPseudo() {
		rev, err := github.GetFullCommitHash(src.Owner, src.Repo, version.GitShortHash, "")
		if err != nil {
			return err
		}
		src.Rev = rev
	} else {
		src.Tag = fmt.Sprintf("v%s", version.Version)
	}

	src.Hash, src.storePath, err = fetch(src)
	if err != nil {
		return fmt.Errorf("fetching '%s@%s': %w", importPath, version, err)
	}

	pkg := Pkg{
		Imports: []string{
			"fetchFromGitHub",
			"stdenv",
			"goPackages",
		},
		ImportPath: importPath,
		Version:    version.Version,
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
	Source                FetchFromGitHub
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
	b.WriteString(fmt.Sprintf("\nsrc = %s;\n\n", src))
	if len(p.PostPatch) > 0 {
		b.WriteString("postPatch = ''\n")
		for _, pf := range p.PostPatch {
			b.WriteString(fmt.Sprintf("%s\n", pf))
		}
		b.WriteString("'';\n\n")
	}
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

func FetchFromGitHubFromImportPath(githubURL string) (FetchFromGitHub, error) {
	var ffg = FetchFromGitHub{}
	parsedURL, err := url.Parse(githubURL)
	if err != nil {
		return ffg, fmt.Errorf("invalid URL: %w", err)
	}

	if parsedURL.Host != "github.com" {
		return ffg, fmt.Errorf("not a valid GitHub URL")
	}

	parts := strings.Split(strings.Trim(parsedURL.Path, "/"), "/")
	if len(parts) < 2 {
		return ffg, fmt.Errorf("invalid GitHub repo URL format")
	}

	owner := parts[0]
	repo := strings.TrimSuffix(parts[1], ".git")
	return FetchFromGitHub{
		Owner: owner,
		Repo:  repo,
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
