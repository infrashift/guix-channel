(define-module (infrashift packages fulcio)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:))

(define-public fulcio
  (package
    (name "fulcio")
    (version "1.8.8")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/sigstore/fulcio/releases/download/v"
                    version "/fulcio-linux-amd64"))
              ;; sha256 hex: 151098c7e837c0849c61dd2b23aed350
              ;;             81b7070317f40c566928a8030ecc01b0
              (sha256
               (base32
                "1c01rh707a18d5b0rx0p0c3vg0ahsfp26ayxc6f89h1px33rh40m"))))
    (build-system copy-build-system)
    (arguments
     (list #:install-plan #~'(("fulcio" "bin/"))
           ;; Prebuilt static pure-Go binary: nothing to strip or validate.
           #:validate-runpath? #f
           #:strip-binaries? #f
           #:phases
           #~(modify-phases %standard-phases
               ;; The source is a bare executable, not an archive.
               (replace 'unpack
                 (lambda* (#:key source #:allow-other-keys)
                   (copy-file source "fulcio")
                   (chmod "fulcio" #o755))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/sigstore/fulcio")
    (synopsis "Sigstore code-signing certificate authority (official release binary)")
    (description
     "Fulcio is Sigstore's certificate authority: it issues short-lived
code-signing certificates bound to OpenID Connect identities.  Installed
from the official upstream release binary (not built from source).")
    (license license:asl2.0)))
