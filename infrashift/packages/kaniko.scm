(define-module (infrashift packages kaniko)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix build-system go)
  #:use-module ((guix licenses) #:prefix license:))

;; Source build, like gocyclo, but with a dependency graph of a few hundred
;; modules rather than none.  It still needs no inputs: upstream commits a
;; complete vendor/ tree (69M), and go-build-system builds in GOPATH mode
;; (GO111MODULE=off), where a top-level vendor/ directory is exactly how
;; imports get resolved.  A side effect worth knowing: GOPATH mode never reads
;; go.mod, so kaniko's "go 1.26.3 / toolchain go1.26.5" directives are ignored
;; and Guix's default `go' builds this fine -- no toolchain download, no
;; #:go pin.  Contrast envbuilder.scm, which cannot use GOPATH mode at all.
;;
;; This is the community fork that succeeded the archived
;; GoogleContainerTools/kaniko.
;;
;; TWO PACKAGES, NOT ONE, and the reason is a network boundary rather than
;; tidiness.  Upstream's two commands have OPPOSITE requirements: `warmer'
;; fetches base images from a registry and cannot work without a network,
;; while `executor' runs inside a hermetic build that must not have one.  A
;; single package puts both in every closure that wants either, so the machine
;; that must not reach a registry ships the tool for reaching one.  Splitting
;; them makes "this image cannot fetch a base image" a property of the closure
;; instead of a rule somebody is asked to keep.
;;
;; What it costs: the vendored tree is compiled twice, once per package.  That
;; is the price of two closures that each carry one binary, and it is the point.

(define kaniko-version "1.28.3")

;; The full commit that tag v1.28.3 points at.  A tag can be moved; a commit
;; cannot.
(define kaniko-commit "e0092dbc17e6aad98efc244c88c2c6d11d5a829a")

(define (kaniko-source)
  "Return the shared source origin for the kaniko commands.  BOTH packages use
this one origin, so both resolve to the SAME fixed-output store path and a
single `guix download --commit=...' in an image builder's .prefetch.sh still
seeds both of them."
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://github.com/osscontainertools/kaniko")
          (commit kaniko-commit)))
    ;; Must equal (url+commit->name url commit) = "<repo>-<sha1:7>" so the
    ;; store item pre-seeded by the image builder's .prefetch.sh is the same
    ;; fixed-output path this origin resolves to.  See gocyclo.scm for the full
    ;; explanation of that trap.
    (file-name "kaniko-e0092db")
    ;; sha256 hex: 233ef7fc919154df64f75631d897cd22
    ;;             5449830b06f47686d4b9bee47f855fbf
    (sha256
     (base32
      "1gszhmzy9gmrsj37dx061f1ljm12rnbxhcanyxjdym4ij7ygfgi3"))))

(define (kaniko-command-package command synopsis* description*)
  "Return a package building exactly one of kaniko's commands.  COMMAND is
upstream's directory name under cmd/ -- \"executor\" or \"warmer\" -- and the
installed binary is renamed to kaniko-COMMAND."
  (package
    (name (string-append "kaniko-" command))
    (version kaniko-version)
    (source (kaniko-source))
    (build-system go-build-system)
    (arguments
     (list #:import-path (string-append "github.com/osscontainertools/kaniko"
                                        "/cmd/" command)
           ;; The module root, NOT the command directory.  GOPATH mode resolves
           ;; imports from the vendor/ tree that lives there, and
           ;; `install-license-files' reads this rather than #:import-path.
           #:unpack-path "github.com/osscontainertools/kaniko"
           #:install-source? #f
           ;; kaniko's tests want a Docker daemon, a registry and the network.
           #:tests? #f
           ;; go-build-system already passes "-ldflags=-s -w"; a later -ldflags
           ;; wins outright rather than merging, so -s -w has to be repeated
           ;; here or the binaries keep their symbol tables.  Mirrors
           ;; upstream's Makefile GO_LDFLAGS.
           #:build-flags
           #~(list (string-append
                    "-ldflags=-s -w -X github.com/osscontainertools/kaniko"
                    "/pkg/version.version=v" #$version))
           #:phases
           #~(modify-phases %standard-phases
               ;; Matches upstream's Makefile and keeps the binaries static and
               ;; self-contained, like every other Go tool in this channel.
               (add-before 'build 'disable-cgo
                 (lambda _
                   (setenv "CGO_ENABLED" "0")))
               ;; "executor" and "warmer" are far too generic for a profile's
               ;; bin/.  Upstream only gets away with them because they live at
               ;; /kaniko/ inside a scratch container.
               (add-after 'install 'rename-binary
                 (lambda _
                   (let ((bin (string-append #$output "/bin")))
                     (rename-file (string-append bin "/" #$command)
                                  (string-append bin "/kaniko-" #$command))))))))
    (home-page "https://github.com/osscontainertools/kaniko")
    (synopsis synopsis*)
    (description description*)
    (license license:asl2.0)))

(define-public kaniko-executor
  (kaniko-command-package
   "executor"
   "Build container images from a Dockerfile without a Docker daemon"
   "kaniko builds container images from a Dockerfile without depending on a
Docker daemon or on privileged mode, which is what makes it usable inside an
unprivileged CI container or Kubernetes pod.  It executes each Dockerfile
instruction in userspace and snapshots the filesystem after each one.

This package installs @command{kaniko-executor}, which performs the build.  It
is deliberately packaged WITHOUT @command{kaniko-warmer}: a build that resolves
every @code{FROM} from a pre-warmed local cache needs no registry client, and
leaving the warmer out means an image carrying the executor cannot reach a
registry at all.

Note that @command{kaniko-executor} is designed to run as root in a throwaway
container and unpacks image layers into @file{/}; pointing it at a live host
filesystem is not a supported mode.  Give it a @code{chroot(2)} of its own."))

(define-public kaniko-warmer
  (kaniko-command-package
   "warmer"
   "Pre-populate a local cache of container base images for kaniko"
   "@command{kaniko-warmer} downloads container base images and writes them
into a local cache laid out the way @command{kaniko-executor} expects to read
it.  Running it ahead of a build is what lets that build resolve every
@code{FROM} offline.

It is packaged apart from the executor because it is the half that NEEDS a
network, and the two therefore belong in different images: the warmer runs in
whichever step is allowed to talk to a registry, and the executor runs in the
step that is not.

The cache is keyed by each base image's digest, and it must be the manifest
digest for the target platform rather than the index digest of a multi-arch
image -- an index digest produces a cache the executor finds and cannot use."))
