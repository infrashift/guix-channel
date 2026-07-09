(define-module (infrashift packages syft)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:))

(define-public syft
  (package
    (name "syft")
    (version "1.46.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/anchore/syft/releases/download/v"
                    version "/syft_" version "_linux_amd64.tar.gz"))
              ;; sha256 hex: d654f678b709eb53c393d38519d5ed7d
              ;;             2e57205529404018614cfefa0fb2b5ca
              (sha256
               (base32
                "1jmmn87zmzjcc4c40h19alh5fbkxxpaik1fkjg1m7sq9nxwgcm6n"))))
    (build-system copy-build-system)
    (arguments
     (list #:install-plan #~'(("syft" "bin/"))
           ;; Prebuilt static pure-Go binary: nothing to strip or validate.
           #:validate-runpath? #f
           #:strip-binaries? #f
           #:phases
           #~(modify-phases %standard-phases
               ;; Unpack flat so the top-level binary stays visible to the
               ;; install plan.
               (replace 'unpack
                 (lambda* (#:key source #:allow-other-keys)
                   (invoke "tar" "xzf" source))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/anchore/syft")
    (synopsis "SBOM generator for container images and filesystems (official release binary)")
    (description
     "Syft generates Software Bills of Materials (SBOMs) from container
images and filesystems.  Installed from the official upstream release binary
(not built from source).")
    (license license:asl2.0)))
