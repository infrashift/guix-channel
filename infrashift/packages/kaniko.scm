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
(define-public kaniko
  (package
    (name "kaniko")
    (version "1.28.3")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/osscontainertools/kaniko")
                    ;; The full commit that tag v1.28.3 points at.  A tag can
                    ;; be moved; a commit cannot.
                    (commit "e0092dbc17e6aad98efc244c88c2c6d11d5a829a")))
              ;; Must equal (url+commit->name url commit) = "<repo>-<sha1:7>"
              ;; so the store item pre-seeded by the image builder's
              ;; .prefetch.sh (guix download --commit=...) is the same
              ;; fixed-output path this origin resolves to.  See gocyclo.scm
              ;; for the full explanation of that trap.
              (file-name "kaniko-e0092db")
              ;; sha256 hex: 233ef7fc919154df64f75631d897cd22
              ;;             5449830b06f47686d4b9bee47f855fbf
              (sha256
               (base32
                "1gszhmzy9gmrsj37dx061f1ljm12rnbxhcanyxjdym4ij7ygfgi3"))))
    (build-system go-build-system)
    (arguments
     ;; The cmd/... wildcard makes a single `go install' produce both binaries.
     ;; It is safe only because the other phases that consume #:import-path are
     ;; disabled: `check' by #:tests? #f, `install' by #:install-source? #f,
     ;; and `install-license-files' reads #:unpack-path instead.
     (list #:import-path "github.com/osscontainertools/kaniko/cmd/..."
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
               (add-after 'install 'rename-binaries
                 (lambda _
                   (let ((bin (string-append #$output "/bin")))
                     (for-each (lambda (command)
                                 (rename-file
                                  (string-append bin "/" command)
                                  (string-append bin "/kaniko-" command)))
                               '("executor" "warmer"))))))))
    (home-page "https://github.com/osscontainertools/kaniko")
    (synopsis "Build container images from a Dockerfile without a Docker daemon")
    (description
     "kaniko builds container images from a Dockerfile without depending on a
Docker daemon or on privileged mode, which is what makes it usable inside an
unprivileged CI container or Kubernetes pod.  It executes each Dockerfile
instruction in userspace and snapshots the filesystem after each one.

Two commands are installed, renamed from upstream's generic @command{executor}
and @command{warmer}: @command{kaniko-executor} performs the build, and
@command{kaniko-warmer} pre-populates a base-image cache.  Note that
@command{kaniko-executor} is designed to run as root in a throwaway container
and unpacks image layers into @file{/}; pointing it at a live host filesystem
is not a supported mode.")
    (license license:asl2.0)))
