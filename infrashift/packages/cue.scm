(define-module (infrashift packages cue)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:))

(define-public cue
  (package
    (name "cue")
    (version "0.17.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/cue-lang/cue/releases/download/v"
                    version "/cue_v" version "_linux_amd64.tar.gz"))
              ;; sha256 hex: e22219a1cb520ab3d660a486ed2222bb
              ;;             7b8e9cb9502a951ce6b8ac668695713f
              (sha256
               (base32
                "0gvijn36db5qwqf9aajhp6f8wyxv48ifv1m4c3bb62jjrfhij8p2"))))
    (build-system copy-build-system)
    (arguments
     (list #:install-plan #~'(("cue" "bin/"))
           ;; Prebuilt static pure-Go binary: nothing to strip or validate,
           ;; and strip can damage Go buildinfo.
           #:validate-runpath? #f
           #:strip-binaries? #f
           #:phases
           #~(modify-phases %standard-phases
               ;; The tarball is flat except for a doc/ subdirectory; the
               ;; default unpack chdirs into the first subdirectory it finds,
               ;; hiding the top-level `cue' binary from the install plan.
               (replace 'unpack
                 (lambda* (#:key source #:allow-other-keys)
                   (invoke "tar" "xzf" source))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://cuelang.org")
    (synopsis "CUE language CLI (official release binary)")
    (description
     "Command-line tool for the CUE data constraint language, installed from
the official upstream release binary (not built from source).")
    (license license:asl2.0)))
