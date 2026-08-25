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

### As a channel (recommended)

Add to `~/.config/guix/channels.scm`. **Include the introduction** — it is what
makes `guix` verify the OpenPGP signature on every commit it fetches:

```scheme
(cons (channel
       (name 'infrashift)
       (url "https://github.com/infrashift/guix-channel")
       (branch "main")
       (introduction
        (make-channel-introduction
         "ce2008bda555bd769c4488b8e39541a4c555fbf9"
         (openpgp-fingerprint
          "7652 899D 3FBF 73B4 6EDA  00BB 0755 1D03 3C04 AAD4"))))
      %default-channels)
```

`--allow-untrusted-channels` is no longer needed, and should not be used: it
would switch off the check this introduction exists to perform.

#### What the introduction actually does

It pins **one commit** and **one fingerprint**, out of band. Everything else in
this repository — including `.guix-authorizations` — is fetched over the network
from a host somebody else could come to control, so none of it can be its own
root of trust. The introduction is the part an attacker who owned this
repository still could not change, because it lives in *your* configuration.

From `ce2008b` onward, guix refuses any commit not signed by a key that
`.guix-authorizations` authorised **in the parent commit**. So a new committer
can only be added by an existing one, and the history of who could sign what is
itself part of the authenticated chain. Commits *before* `ce2008b` are not
authenticated and cannot be — authentication has to start somewhere a human
chose deliberately.

The public keys live on the [`keyring`](../../tree/keyring) branch, which is
where guix looks by default.

Verify the pin against this repository before trusting it:

```sh
git clone https://github.com/infrashift/guix-channel && cd guix-channel
git verify-commit ce2008bda555bd769c4488b8e39541a4c555fbf9
```

### As a load path (package development only)

Point any `guix` command at a checkout with `-L`:

```sh
guix build -L /path/to/guix-channel cue
```

This bypasses the channel machinery entirely: no commit, no signature, no
authentication. It is for iterating on a package definition, and an artifact
built this way has provenance that does not describe it. `infrashift/libvirt-qemu-kvm`
exposes it as `CHANNEL_DEV=1` and warns on every build that uses it.

## Licence

Apache 2.0 — see [LICENSE](LICENSE). That covers the **package definitions** in
this repository. The software each one builds carries its own licence, declared
in the package record itself.

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
