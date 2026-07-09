# infrashift guix-channel

Out-of-tree [Guix](https://guix.gnu.org) package definitions for infrashift
projects. Modules live at the repo root under `infrashift/`, e.g.
`(infrashift packages cue)`.

## Packages

All wrap official upstream release binaries pinned by version + sha256
(source-built go-build-system packages may replace them later):

- **cue** — CUE language CLI (`cuelang.org`)
- **grype** — Anchore vulnerability scanner
- **syft** — Anchore SBOM generator
- **cosign** — Sigstore artifact signing/verification
- **fulcio** — Sigstore code-signing certificate authority (server)
- **rekor-cli** / **rekor-server** — Sigstore transparency log client/server

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
