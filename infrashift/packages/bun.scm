(define-module (infrashift packages bun)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages base)         ; glibc
  #:use-module (gnu packages compression)  ; unzip
  #:use-module (gnu packages elf)          ; patchelf
  #:use-module ((guix licenses) #:prefix license:))

(define-public bun
  (package
    (name "bun")
    (version "1.3.14")
    (source (origin
              (method url-fetch)
              ;; bun-linux-x64.zip, not the -baseline variant.  Baseline is the
              ;; build for CPUs without AVX2; if a target node ever lacks it,
              ;; bun-linux-x64-baseline.zip is a drop-in swap (new hash).
              (uri (string-append
                    "https://github.com/oven-sh/bun/releases/download/bun-v"
                    version "/bun-linux-x64.zip"))
              ;; sha256 hex: 951ee2aee855f08595aeec6225226a29
              ;;             8d3fea83a3dcd6465c09cbccdf7e848f
              (sha256
               (base32
                "13w4gvgwrjq9bi3ddp53hgm3z399d8i2aqpcmsaqbw2mx2pf47lm"))))
    (build-system copy-build-system)
    ;; Unlike every other package here, bun is NOT static: it is a glibc-linked
    ;; binary built against a filesystem layout Guix does not have, so its
    ;; ELF interpreter has to be repointed at glibc in the store.
    (native-inputs (list patchelf unzip))
    (inputs (list glibc))
    (arguments
     (list #:install-plan #~'(("bun" "bin/"))
           ;; A 92 MB Zig/JavaScriptCore binary: stripping it is not worth the
           ;; risk, and it ships unstripped by design.
           #:strip-binaries? #f
           ;; There is no RUNPATH to validate -- see the phase below for why
           ;; setting one is not an option here.
           #:validate-runpath? #f
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'install 'patchelf-interpreter
                 (lambda* (#:key inputs #:allow-other-keys)
                   (let* ((bun (string-append #$output "/bin/bun"))
                          ;; Observed with `readelf -d' on the 1.3.14 binary,
                          ;; NEEDED: libc.so.6, ld-linux-x86-64.so.2,
                          ;; libpthread.so.0, libdl.so.2, libm.so.6 -- every
                          ;; one of them from glibc, and notably NO libstdc++,
                          ;; so glibc is the only input required.
                          (ld (search-input-file
                               inputs "/lib/ld-linux-x86-64.so.2")))
                     ;; ONLY the interpreter, never --set-rpath.  Measured on
                     ;; 1.3.14: --set-interpreter alone leaves a working
                     ;; binary, while --set-rpath (with or without the
                     ;; interpreter change) produces one that segfaults
                     ;; immediately -- patchelf cannot grow this binary's
                     ;; headers without corrupting it.
                     ;;
                     ;; Omitting RUNPATH is safe because the interpreter we
                     ;; point at is glibc's own ld.so, whose built-in default
                     ;; search path is that same glibc's lib directory;
                     ;; verified with LD_TRACE_LOADED_OBJECTS that all five
                     ;; NEEDED libraries resolve into the store.
                     ;;
                     ;; A wrapper invoking ld.so explicitly was tried first and
                     ;; rejected: it makes process.execPath report the loader,
                     ;; so bun spawning itself fails (exit 127).
                     (chmod bun #o755)
                     (invoke "patchelf" "--set-interpreter" ld bun))))
               (add-after 'patchelf-interpreter 'symlink-bunx
                 (lambda _
                   ;; `bunx' is bun in package-runner mode, selected from
                   ;; argv[0]; upstream ships it as a symlink.
                   (symlink "bun" (string-append #$output "/bin/bunx")))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://bun.sh")
    (synopsis "JavaScript runtime, bundler and package manager (official release binary)")
    (description
     "Bun is a JavaScript runtime with a built-in bundler, test runner and
npm-compatible package manager.  Installed from the official upstream release
binary (not built from source).")
    ;; Bun's own code is MIT; it statically links JavaScriptCore/WebKit, which
    ;; is LGPL-2 (see upstream LICENSE.md).
    (license (list license:expat license:lgpl2.0))))
