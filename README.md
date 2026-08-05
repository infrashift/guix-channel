# infrashift guix-channel

Out-of-tree [Guix](https://guix.gnu.org) package definitions for infrashift
projects. Modules live at the repo root under `infrashift/`, e.g.
`(infrashift packages cue)`.

## Packages

Unless noted, these wrap official upstream release binaries pinned by version
+ sha256 (source-built go-build-system packages may replace them later):

- **cue** — CUE language CLI (`cuelang.org`)
- **grype** — Anchore vulnerability scanner
- **syft** — Anchore SBOM generator
- **cosign** — Sigstore artifact signing/verification
- **fulcio** — Sigstore code-signing certificate authority (server)
- **rekor-cli** / **rekor-server** — Sigstore transparency log client/server
- **bun** — JavaScript runtime / bundler / package manager. The only wrap that
  is not static: glibc-linked, so its ELF interpreter is repointed with
  `patchelf` at build time.
- **ruff** — Python linter and formatter. Wraps the **musl** asset, which is
  static-pie and therefore needs no patching.
- **golangci-lint** — aggregating Go linter runner
- **gocyclo** — cyclomatic complexity reporter for Go. **Built from source**
  (`go-build-system`): upstream publishes no release assets. Its `go.mod` has
  zero dependencies, so the build needs no inputs.

These four exist because Guix 1.5.0 has no upstream package for them. It does
already carry `go`, `node`, `python`, `python-pytest`, `uv`, `govulncheck` and
`vips` — check upstream before adding anything here.

## Usage

### As a load path (local builds, no channel machinery)

Point any `guix` command at a checkout of this repo with `-L`:

```sh
guix build -L /path/to/guix-channel cue
guix system image -L /path/to/guix-channel my-config.scm
```

This is how `labs/guix/image/build.sh devspace` in the
`infrashift/libvirt-qemu-kvm` repo consumes it (the repo is bind-mounted at
`/channel` inside the image-builder container).

### As a channel (guix pull)

Add to `~/.config/guix/channels.scm`:

```scheme
(cons (channel
       (name 'infrashift)
       (url "https://github.com/infrashift/guix-channel")
       (branch "main"))
      %default-channels)
```

Until a channel introduction (signing) is set up, `guix pull` requires
`--allow-untrusted-channels`.
