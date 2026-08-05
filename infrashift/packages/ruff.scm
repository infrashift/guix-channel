(define-module (infrashift packages ruff)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:))

(define-public ruff
  (package
    (name "ruff")
    (version "0.16.1")
    (source (origin
              (method url-fetch)
              ;; The MUSL build deliberately, not the gnu one: upstream's musl
              ;; target is static-pie, so it needs no interpreter patching and
              ;; no glibc input.  The gnu tarball would drag in the whole
              ;; patchelf dance that bun.scm has to do.
              (uri (string-append
                    "https://github.com/astral-sh/ruff/releases/download/"
                    version "/ruff-x86_64-unknown-linux-musl.tar.gz"))
              ;; sha256 hex: 23469683052cd2db1589f15032dd1751
              ;;             b2a3f212062e9fc901b0776d25fb36bc
              (sha256
               (base32
                "1g1nzcjnsxxh074rybh62bra7cji2zfk4l7ii4axplic0n1rcii3"))))
    (build-system copy-build-system)
    (arguments
     ;; One top-level directory in the tarball, so the default unpack chdirs
     ;; into it and the plan below is relative to that.
     (list #:install-plan #~'(("ruff" "bin/"))
           ;; Statically linked (static-pie): no RUNPATH to validate, and it
           ;; arrives stripped already.
           #:validate-runpath? #f
           #:strip-binaries? #f))
    (supported-systems '("x86_64-linux"))
    (home-page "https://docs.astral.sh/ruff/")
    (synopsis "Python linter and formatter (official release binary)")
    (description
     "Ruff is a Python linter and code formatter written in Rust, fast enough
to run on every save and in a build gate.  Installed from the official
upstream release binary (not built from source).")
    (license license:expat)))
