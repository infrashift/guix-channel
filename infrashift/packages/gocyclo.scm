(define-module (infrashift packages gocyclo)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system go)
  #:use-module ((guix licenses) #:prefix license:))

;; The one package in this channel that is NOT a release-binary wrap: upstream
;; publishes no release assets at all, only tags.  It is also the cheapest
;; possible source build -- gocyclo's go.mod declares zero dependencies, so
;; go-build-system needs no inputs.
(define-public gocyclo
  (package
    (name "gocyclo")
    (version "0.6.0")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/fzipp/gocyclo")
                    ;; The full commit that tag v0.6.0 points at.  A tag can be
                    ;; moved; a commit cannot.
                    (commit "62aa1f84d9ea7d68ecc499a74e98f188f63b650e")))
              ;; Must equal (url+commit->name url commit) = "<repo>-<sha1:7>"
              ;; so the store item pre-seeded by the image builder's
              ;; .prefetch.sh (guix download --commit=...) is the same
              ;; fixed-output path this origin resolves to.  The daemon cannot
              ;; download it itself: it runs as container-root and `guix
              ;; perform-download' refuses UID 0.  Same trap as
              ;; lazyvim-starter in libvirt-qemu-kvm's system-devspace.scm.
              (file-name "gocyclo-62aa1f8")
              (sha256
               (base32
                "1w2h8qlifrskn8g8zcwb6banr9si0vck9y8irg1r51mc98cjv36l"))))
    (build-system go-build-system)
    (arguments
     (list #:import-path "github.com/fzipp/gocyclo/cmd/gocyclo"
           #:unpack-path "github.com/fzipp/gocyclo"
           #:install-source? #f))
    (home-page "https://github.com/fzipp/gocyclo")
    (synopsis "Cyclomatic complexity reporter for Go")
    (description
     "gocyclo calculates the cyclomatic complexity of Go functions and can
fail a build when a function exceeds a threshold.")
    (license license:bsd-3)))
