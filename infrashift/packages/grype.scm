(define-module (infrashift packages grype)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:))

(define-public grype
  (package
    (name "grype")
    (version "0.115.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/anchore/grype/releases/download/v"
                    version "/grype_" version "_linux_amd64.tar.gz"))
              ;; sha256 hex: 3fad92940650e514c0aa2dad83526942
              ;;             a055e210cec09a8a59d9c024adc2b90e
              (sha256
               (base32
                "03mrqanj9h6rb659mh6f23i5b822d5987b9dmb019rah0sa95b9z"))))
    (build-system copy-build-system)
    (arguments
     (list #:install-plan #~'(("grype" "bin/"))
           ;; Prebuilt static pure-Go binary: nothing to strip or validate.
           #:validate-runpath? #f
           #:strip-binaries? #f
           #:phases
           #~(modify-phases %standard-phases
               ;; Unpack flat so the top-level binary stays visible to the
               ;; install plan (default unpack chdirs into a subdirectory
               ;; when it sees one).
               (replace 'unpack
                 (lambda* (#:key source #:allow-other-keys)
                   (invoke "tar" "xzf" source))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/anchore/grype")
    (synopsis "Vulnerability scanner for container images and filesystems (official release binary)")
    (description
     "Grype scans container images, filesystems and SBOMs for known
vulnerabilities.  Installed from the official upstream release binary (not
built from source).")
    (license license:asl2.0)))
