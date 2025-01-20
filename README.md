# `gobuild.nix`

Go builder for Nix with per-Go-module fetching and builds.

## Status

Early, not fully baked.

## Motivations

### Incremental fetching & building

`buildGoModule` fetches and builds whole dependency graphs as one big derivation. This is done based on the `go.mod` file
of the source, which pins the versions of module dependencies. The result of the fixed output derivation is captured as
`vendorHash`.

This approach wastes bandwidth, storage and build time, as the same dependency is downloaded into the dependency derivation
of multiple packages.

By using [`GOCACHEPROG`](https://github.com/golang/go/issues/59719) we can achieve per-module granular builds.
This has the potential to significantly cut down on build times.

### Security

Nixpkgs currently has a weak security posture regarding vulnerable Go dependencies.
Because `buildGoModule` has no insight into the dependency graph it has no actual idea of what libraries are shipped and whether they're vulnerable.
It's difficult to mitigate vulnerabilities downstream in nixpkgs where needed, which would
require patching each packages `go.mod` individually.

gobuild.nix creates a package set for all Go module dependencies, and models the dependency graph within Nix.
This way, security updates of a dependency propagate to all packages depending on it.
By having only one centrally managed version of a dependency it's easier to ensure we don't ship known vulnerable code.

### Composability

The "fix" for packages that fail after a compiler version bump is often to pin that package to use an older compiler.
Having a central set which we can patch could make many older compiler pins unnecessary.

## Adoption in nixpkgs

If nixpkgs were to adopt this as it's Go builders, it would imply creating a Go package set.
This has many benefits, but also some challenges.

  - Tooling would have to be created to keep the set up to date automatically depending on what leaf packages need.
  - It's a dramatic shift away from how `buildGoModule` works
  - Each package needs to record it's build inputs, now they're all grouped into a single hash
  - Much more

## TODO

- [ ] Pre-build Go stdlib
  Currently the stdlib isn't pre-compiled, and stdlib cache ends up in whatever derivations first touch those code paths.
- [ ] Propagate transitive dependencies
- [ ] Potentially rewrite go.mod to based on version available in Go package set

## Related

- [nix-gocacheprog](https://github.com/dnr/nix-gocacheprog)
- [build-go-cache](https://github.com/numtide/build-go-cache)
- [Investigate packaging Rust crates separately](https://github.com/NixOS/nixpkgs/issues/333702)
