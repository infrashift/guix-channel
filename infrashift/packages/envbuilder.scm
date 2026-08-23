(define-module (infrashift packages envbuilder)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix build-system go)
  #:use-module ((guix licenses) #:prefix license:))

;; The version lives here rather than only in the package field because the
;; vendor origin below is defined outside the package body and so cannot see
;; (version ...).  rekor.scm sets the precedent for file-local helpers.
(define %envbuilder-version "1.3.0")

;; Unlike kaniko, envbuilder commits no vendor/ tree, and it pulls roughly 700
;; modules (1360 go.sum lines, 129M vendored).  A Guix build has no network, so
;; the dependency tree has to arrive as a hash-pinned artifact.  This is
;; `go mod vendor' run once at the commit pinned below and published as a
;; release asset on this very repo.
;;
;; That is safe to re-derive: `go mod vendor' is deterministic -- two
;; independent clones of v1.3.0 vendor to a byte-identical tree -- so
;; regenerating reproduces this hash rather than inventing a new one.  Use
;; tools/vendor-tarball.sh, which also applies the reproducible tar flags the
;; hash depends on.
;;
;; A plain URL was chosen over a custom fixed-output "go mod vendor"
;; derivation deliberately: the image builder's .prefetch.sh can pre-seed a URL
;; with `guix download', and its daemon cannot fetch anything itself.
(define envbuilder-vendor
  (origin
    (method url-fetch)
    (uri (string-append
          "https://github.com/infrashift/guix-channel/releases/download/"
          "envbuilder-vendor-" %envbuilder-version
          "/envbuilder-" %envbuilder-version "-vendor.tar.gz"))
    ;; sha256 hex: b9d36ebf42be6ebd897fa4de3878d98e
    ;;             c829fa2e394e94366ca1c3b72cc50b95
    (sha256
     (base32
      "158bqlnbghx1dhv98kir5vx2kj4fv5w3ipm4gy4vsvmy8aznxlxr"))))

(define-public envbuilder
  (package
    (name "envbuilder")
    (version %envbuilder-version)
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/coder/envbuilder")
                    ;; The full commit that tag v1.3.0 points at.  A tag can be
                    ;; moved; a commit cannot.  The vendor tarball above is
                    ;; generated from this same commit; bump them together.
                    (commit "da95f80ea89fc615b85441da107c29004061df6a")))
              ;; Must equal (url+commit->name url commit) = "<repo>-<sha1:7>";
              ;; see gocyclo.scm for why the image builder depends on this.
              (file-name "envbuilder-da95f80")
              ;; sha256 hex: 2f4cae4f4ca5dd168860ef320ff72771
              ;;             059e249f4a9e85fa52ba6e2842ddbf03
              (sha256
               (base32
                "00xzvm12hvmsabx8b7jakwj9w1bi4zvhycpgc241dpd59i7swk1g"))))
    (build-system go-build-system)
    (arguments
     (list #:import-path "github.com/coder/envbuilder"
           #:install-source? #f
           ;; The test suite drives a local Docker registry over the network.
           #:tests? #f
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'unpack-vendor
                 (lambda _
                   (with-directory-excursion "src/github.com/coder/envbuilder"
                     (invoke "tar" "xf" #$envbuilder-vendor))))
               ;; go-build-system builds in GOPATH mode (GO111MODULE=off).
               ;; envbuilder cannot: its go.mod `replace's tailscale.com onto a
               ;; fork, and the vendored tailscale/golang-x-crypto still
               ;; carries the canonical import comment
               ;;   // import "golang.org/x/crypto/ssh"
               ;; which GOPATH mode enforces and module mode ignores.  Under
               ;; GOPATH the build dies with `expects import
               ;; "golang.org/x/crypto/ssh"'.  So build in module mode against
               ;; vendor/ instead -- still entirely offline.
               (replace 'build
                 (lambda _
                   (with-directory-excursion "src/github.com/coder/envbuilder"
                     (setenv "GO111MODULE" "on")
                     (setenv "GOFLAGS" "-mod=vendor -v")
                     (setenv "GOPROXY" "off")
                     ;; Never reach for a newer toolchain: with no network that
                     ;; fails obscurely.  Fail on the go.mod check instead.
                     (setenv "GOTOOLCHAIN" "local")
                     ;; Static, self-contained binary, as upstream builds it.
                     (setenv "CGO_ENABLED" "0")
                     ;; GOBIN is already $out/bin, so `go install' lands right.
                     ;; The tag ldflag takes NO "v" prefix: buildinfo.Version()
                     ;; prepends one, and "v1.3.0" here yields "vv1.3.0".
                     (invoke "go" "install" "-trimpath"
                             (string-append
                              "-ldflags=-s -w -X github.com/coder/envbuilder"
                              "/buildinfo.tag=" #$version)
                             "./cmd/envbuilder")))))))
    (home-page "https://github.com/coder/envbuilder")
    (synopsis "Build a development environment from a devcontainer.json")
    (description
     "envbuilder turns a repository containing a @file{devcontainer.json} or a
Dockerfile into a running development environment, building the image in place
and then executing into it.  It embeds kaniko as a library, so it needs neither
a Docker daemon nor privileged mode and can run as the entrypoint of an
unprivileged container.

Like @command{kaniko-executor}, it expects to own the filesystem it starts in:
it unpacks the built image over @file{/}.  Run it in a container, not on a
host.")
    (license license:asl2.0)))
