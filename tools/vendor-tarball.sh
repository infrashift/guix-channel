#!/usr/bin/env bash
#
# Regenerate the pinned `go mod vendor' tarball for a source-built Go package
# in this channel.
#
#   tools/vendor-tarball.sh <package> <tag> [outdir]
#   tools/vendor-tarball.sh envbuilder v1.3.0
#
# Why this exists: Guix build environments have no network, so a Go package
# whose upstream does not commit a vendor/ tree cannot resolve its own
# dependencies.  We run `go mod vendor' once, here, and publish the result as a
# release asset that the package definition pins by sha256.
#
# `go mod vendor' is deterministic -- two independent clones of the same tag
# vendor to a byte-identical tree -- so this script reproduces the pinned hash
# rather than inventing a new one each run.  The tar flags below are the other
# half of that guarantee: without them the archive picks up clone mtimes, the
# invoking user's uid/gid and readdir order, and the hash drifts.
#
# Output: the full commit SHA and (file-name ...) value for the git-fetch
# origin, the tarball, its sha256 in both the hex-comment and (base32 ...)
# forms this channel uses, and the `gh' commands to publish it.

set -euo pipefail

usage() {
	echo "usage: ${0##*/} <package> <tag> [outdir]" >&2
	echo "  package: one of ${!UPSTREAM[*]}" >&2
	exit 2
}

# package -> upstream git URL.  Adding another vendored package is one line.
declare -A UPSTREAM=(
	[envbuilder]="https://github.com/coder/envbuilder"
)

[[ $# -ge 2 ]] || usage
pkg=$1
tag=$2
outdir=${3:-$PWD}

[[ -v UPSTREAM[$pkg] ]] || usage
url=${UPSTREAM[$pkg]}
version=${tag#v}

command -v go >/dev/null || { echo "error: go not found on PATH" >&2; exit 1; }

workdir=$(mktemp -d)
# The Go module cache is written read-only, so a plain `rm -rf' leaves most of
# it (and ~1.5G of disk) behind.  Make it writable first.
cleanup() { chmod -R u+w "$workdir" 2>/dev/null || true; rm -rf "$workdir"; }
trap cleanup EXIT

echo "==> cloning $url at $tag"
git -c advice.detachedHead=false \
	clone --quiet --depth 1 --branch "$tag" "$url" "$workdir/$pkg"

commit=$(git -C "$workdir/$pkg" rev-parse HEAD)
echo
echo "    (commit \"$commit\")"
echo "    (file-name \"$pkg-${commit:0:7}\")"
echo

echo "==> go mod vendor (this downloads the full module graph; it is slow)"
(
	cd "$workdir/$pkg"
	# GOFLAGS= so an inherited -mod=vendor does not defeat the vendoring
	# itself; GOTOOLCHAIN=local so a `toolchain' directive cannot silently
	# swap in a different Go and change the output.
	GOFLAGS= GOTOOLCHAIN=local GO111MODULE=on GOMODCACHE="$workdir/modcache" \
		go mod vendor
)

mkdir -p "$outdir"
tarball="$outdir/$pkg-$version-vendor.tar.gz"

echo "==> writing $tarball"
(
	cd "$workdir/$pkg"
	# Reproducible archive: fixed member order, zeroed mtimes, numeric
	# root:root ownership, and gzip -n so the timestamp stays out of the
	# gzip header.  Change any of these and the pinned hash changes.
	tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
		-cf - vendor | gzip -9n
) > "$tarball"

hex=$(sha256sum "$tarball" | cut -d' ' -f1)

if command -v guix >/dev/null; then
	b32=$(guix hash "$tarball")
else
	# Nix-base32: 32-char alphabet with e, o, u and t removed, emitted
	# most-significant character first.  52 characters for a 32-byte digest.
	b32=$(python3 - "$tarball" <<'PY'
import hashlib, sys

ALPHABET = "0123456789abcdfghijklmnpqrsvwxyz"

with open(sys.argv[1], "rb") as f:
    digest = hashlib.file_digest(f, "sha256").digest()

out = []
for n in reversed(range((len(digest) * 8 - 1) // 5 + 1)):
    b = n * 5
    i, j = divmod(b, 8)
    c = digest[i] >> j
    if i + 1 < len(digest):
        c |= digest[i + 1] << (8 - j)
    out.append(ALPHABET[c & 0x1F])
print("".join(out))
PY
	)
fi

echo
echo "    ;; sha256 hex: ${hex:0:32}"
echo "    ;;             ${hex:32:32}"
echo "    (sha256 (base32 \"$b32\"))"
echo
echo "==> publish with:"
echo "    gh release create $pkg-vendor-$version \\"
echo "        --repo infrashift/guix-channel \\"
echo "        --title '$pkg $version vendored dependencies' \\"
echo "        --notes 'Output of \`go mod vendor\` at $commit. Pinned by infrashift/packages/$pkg.scm.' \\"
echo "        '$tarball'"
