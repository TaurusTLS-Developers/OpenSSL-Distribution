OpenSSL Distribution Package
============================

This package contains the OpenSSL executable, shared libraries, static libraries (stripped), C headers, and documentation.

Package Layout:
---------------
* version.txt         - OpenSSL version in this package [non-redistributable]
* openssl             - The OpenSSL command-line utility [redistributable/optional]
* libcrypto / libssl  - Shared libraries [redistributable/required] 
* install_symlinks.sh - (POSIX only) Script to restore shared library symlinks [redistributable/optional] 
* engines/            - OpenSSL engines [redistributable/optional] 
* providers/          - OpenSSL providers [redistributable/optional] 
* doc/                - Developers Documentation [non-redistributable] 
* include/            - C Header files [non-redistributable] 
* lib/import/         - Import libraries (Windows only) [non-redistributable] 
* lib/static/         - Static libraries (.lib / .a) [non-redistributable]

Linking Instructions:
---------------------
* Windows Dynamic: Link against the import libraries in `lib/import/` (which point to the DLLs in the root).
* Windows Static:  Link against the static libraries in `lib/static/` (Compiled with /MD Dynamic CRT).
* POSIX Dynamic:   Link directly against the shared libraries (.so / .dylib) in the root directory.
* POSIX Static:    Link against the static archives (.a) in `lib/static/`.

Deployment Instructions (Linux / macOS / Unix):
-----------------------------------------------
Windows file systems fail to extract Unix symbolic links. To ensure cross-platform compatibility, this archive contains only the physical shared library files.

If this package includes the 'install_symlinks.sh' script, you MUST run it from the root of the extracted directory to recreate the required library symlinks (e.g., libcrypto.so -> libcrypto.so.X).

$ cd <extracted_directory>
$ sh ./install_symlinks.sh

Windows Users:
--------------
Windows does not use symlinks for OpenSSL DLLs. You can safely ignore or delete the shell script.
