(define-module (infrashift packages golangci-lint)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:))

(define-public golangci-lint
  (package
    (name "golangci-lint")
    (version "2.12.2")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/golangci/golangci-lint/releases/download/v"
                    version "/golangci-lint-" version "-linux-amd64.tar.gz"))
              ;; sha256 hex: 8df580d2670fed8fa984aac0507099af
              ;;             8df275e665215f5c7a2ae3943893a553
              (sha256
               (base32
                "0lx5jcw99qrag9f5y8b5wrsz53dgk5q51h5ahjlqzv8gcz981xcd"))))
    (build-system copy-build-system)
    (arguments
     ;; Unlike cue's, this tarball has exactly one top-level directory
     ;; (golangci-lint-<version>-linux-amd64/), so the DEFAULT unpack -- which
     ;; chdirs into the sole subdirectory -- lands where the install plan
     ;; expects.  Do not copy cue.scm's flat-unpack workaround here.
     (list #:install-plan #~'(("golangci-lint" "bin/"))
           ;; Prebuilt static pure-Go binary: nothing to strip or validate,
           ;; and strip can damage Go buildinfo.
           #:validate-runpath? #f
           #:strip-binaries? #f))
    (supported-systems '("x86_64-linux"))
    (home-page "https://golangci-lint.run")
    (synopsis "Aggregating linter runner for Go (official release binary)")
    (description
     "golangci-lint runs many Go linters in parallel over a package graph it
parses once, which is what makes it fast enough for a build gate.  Installed
from the official upstream release binary (not built from source).")
    (license license:gpl3)))
