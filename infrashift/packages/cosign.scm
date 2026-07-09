(define-module (infrashift packages cosign)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:))

(define-public cosign
  (package
    (name "cosign")
    (version "3.1.1")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/sigstore/cosign/releases/download/v"
                    version "/cosign-linux-amd64"))
              ;; sha256 hex: ae1ecd212663f3693ad9edf8b1a18390
              ;;             0c9a52d3155ba6e354237f9a0f6463fc
              (sha256
               (base32
                "1z33ch7rlzr3akiscnqmsd99l34hhfhv3y7dv4x6kwv34qhws7mf"))))
    (build-system copy-build-system)
    (arguments
     (list #:install-plan #~'(("cosign" "bin/"))
           ;; Prebuilt static pure-Go binary: nothing to strip or validate.
           #:validate-runpath? #f
           #:strip-binaries? #f
           #:phases
           #~(modify-phases %standard-phases
               ;; The source is a bare executable, not an archive.
               (replace 'unpack
                 (lambda* (#:key source #:allow-other-keys)
                   (copy-file source "cosign")
                   (chmod "cosign" #o755))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/sigstore/cosign")
    (synopsis "Container signing and verification tool (official release binary)")
    (description
     "Cosign signs and verifies container images and other artifacts, with
optional keyless signing via the Sigstore public-good instance.  Installed
from the official upstream release binary (not built from source).")
    (license license:asl2.0)))
