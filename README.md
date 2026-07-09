# infrashift guix-channel

Out-of-tree [Guix](https://guix.gnu.org) package definitions for infrashift
projects. Modules live at the repo root under `infrashift/`, e.g.
`(infrashift packages cue)`.

## Packages

- **cue** — CUE language CLI (`cuelang.org`), wrapping the official upstream
  release binary pinned by version + sha256. (A source-built go-build-system
  package may replace it later.)

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
