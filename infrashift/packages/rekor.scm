(define-module (infrashift packages rekor)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix base32)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:))

(define (rekor-binary-package binary-name hash-base32 synopsis* description*)
  "Return a package for one prebuilt rekor release binary.  HASH-BASE32 is
the nix-base32 sha256 of the raw binary (the (base32 ...) macro needs a
literal, so the helper converts the string at run time instead)."
  (package
    (name binary-name)
    (version "1.5.3")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/sigstore/rekor/releases/download/v"
                    version "/" binary-name "-linux-amd64"))
              (sha256 (nix-base32-string->bytevector hash-base32))))
    (build-system copy-build-system)
    (arguments
     (list #:install-plan #~'((#$binary-name "bin/"))
           ;; Prebuilt static pure-Go binary: nothing to strip or validate.
           #:validate-runpath? #f
           #:strip-binaries? #f
           #:phases
           #~(modify-phases %standard-phases
               ;; The source is a bare executable, not an archive.
               (replace 'unpack
                 (lambda* (#:key source #:allow-other-keys)
                   (copy-file source #$binary-name)
                   (chmod #$binary-name #o755))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/sigstore/rekor")
    (synopsis synopsis*)
    (description description*)
    (license license:asl2.0)))

(define-public rekor-cli
  (rekor-binary-package
   "rekor-cli"
   ;; sha256 hex: c519704f8e665c192dbf190d3ac97706
   ;;             8d3e74163951a50b3d34972478e5bbb0
   "1c5vwmw295rl7l5sal9r2rs3x386fz4kl38rpwnijp36ir7p06f5"
   "Sigstore transparency log client (official release binary)"
   "Command-line client for Rekor, Sigstore's signature transparency log.
Installed from the official upstream release binary (not built from
source)."))

(define-public rekor-server
  (rekor-binary-package
   "rekor-server"
   ;; sha256 hex: 502e3111dc777c043496bd8504af9a1d
   ;;             09153bcba6f1277a8f0939907be96868
   "0s38x5xr0f89ixx2gwd6rcxia28xkaph91dxjqs08z3pvh8k2bjh"
   "Sigstore transparency log server (official release binary)"
   "Rekor server: Sigstore's append-only signature transparency log.
Installed from the official upstream release binary (not built from
source)."))
