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
- **kaniko** — builds container images from a Dockerfile without a Docker
  daemon (the `osscontainertools` fork that succeeded the archived
  `GoogleContainerTools/kaniko`). **Built from source**; upstream publishes no
  release assets but does commit a `vendor/` tree, which is exactly how
  `go-build-system`'s GOPATH mode resolves imports, so the build needs no
  inputs. Installs `kaniko-executor` and `kaniko-warmer`, renamed from
  upstream's far-too-generic `executor` and `warmer`.
- **envbuilder** — builds a development environment from a `devcontainer.json`
  or Dockerfile, embedding kaniko as a library. **Built from source**, but
  unlike kaniko it commits no `vendor/` tree and pulls ~700 modules, so its
  dependencies come from a pinned vendor tarball — see [Vendored source
  builds](#vendored-source-builds).

These exist because Guix 1.5.0 has no upstream package for them. It does
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

## Vendored source builds

Guix build environments have no network, so a Go package whose upstream does
not commit a `vendor/` tree cannot resolve its own dependencies. For those,
`go mod vendor` is run once, ahead of time, and the result is published as a
release asset on this repo that the package definition pins by sha256.

`go mod vendor` is deterministic — two independent clones of the same tag
vendor to a byte-identical tree — so regenerating an artifact reproduces the
pinned hash instead of inventing a new one, provided the archive is written
with the reproducible `tar` flags. `tools/vendor-tarball.sh` encapsulates all
of that:

```sh
tools/vendor-tarball.sh envbuilder v1.3.0
```

It prints the resolved commit and `(file-name ...)` for the `git-fetch` origin,
writes `<pkg>-<version>-vendor.tar.gz`, prints its sha256 in both the
hex-comment and `(base32 ...)` forms this channel uses, and prints the `gh`
command to publish it. Release assets are tagged `<pkg>-vendor-<version>`.

Bumping such a package means updating the commit, both hashes and the version
together — the tarball must be regenerated from the same commit the source
origin pins, or the vendored tree will not match `go.mod`.
