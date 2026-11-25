# xylem Toolchain

Cross-compilation image for building Leaf against xylem, the way
`mlp1-toolchain` serves Leaf on stock LoongOS.

The SDK is built by Buildroot 2026.02.3 from xylem's own toolchain settings:
the same GCC, glibc and kernel headers xylem's image is built with. Leaf's
library set is added on top, every library from the same Buildroot. A binary
built here runs on xylem; it doesn't run on stock LoongOS, whose glibc (2.38)
is older. For stock, keep using `mlp1-toolchain`.

The image is blob-free. Its EGL, GLES and GBM come from Mesa built with the
softpipe driver only, which gives the standard libraries and headers to link
against. On the device the Mali blob answers to the same sonames. No libmali,
no stock firmware files, no device blobs.

## What's in it

Recorded by `scripts/sdk-manifest.sh` into `dist/xylem-sdk-linux-<arch>.txt`;
`make manifest` prints the same from the image.

| | |
|---|---|
| Source | xylem `4a7975a`, Buildroot 2026.02.3 |
| Compiler | GCC 15.2.0 (C and C++), binutils 2.44 |
| C library | glibc 2.42 |
| Kernel headers | 6.19.14 (xylem's kernel is 7.1.2) |
| Tuple | `aarch64-buildroot-linux-gnu`, `-mcpu=cortex-a55` |

Libraries, all Buildroot 2026.02.3's packages:

- SDL2 2.32.10 (Wayland, KMSDRM, GLES, ALSA, libudev), SDL2_image 2.8.12,
  SDL2_ttf 2.24.0, SDL2_mixer 2.6.3;
- EGL, GLES 2/3 and GBM from Mesa 26.0.1 (softpipe), libdrm 2.4.131, the
  Vulkan 1.4.317 headers and loader;
- wayland 1.24.0 (client, EGL, and the host `wayland-scanner`),
  wayland-protocols 1.45, libxkbcommon 1.9.2;
- alsa-lib 1.2.15.3, PulseAudio 17.0's client libraries, eudev's libudev;
- sqlite 3.51.3 (FTS3), freetype 2.14.3, harfbuzz 12.3.2, libpng 1.6.58,
  libjpeg-turbo 3.1.2, zlib, json-c 0.18, libcurl 8.20.0 with OpenSSL
  3.6.2, CA certificates;
- libxcrypt 4.5.2 with glibc's old API (`libcrypt.so.1`);
- for the cores, as `mlp1-toolchain` has them: fmt 12.1.0, ICU 78.2, inih
  62, pixman 0.46.4.

The set is `configs/leaf-sdk.fragment`; xylem's toolchain lines are
`configs/xylem-base.fragment`. In the manifest, freetype2 (26.6.20) and
wayland-egl (18.1.0) show their pkg-config versions, which aren't the
release numbers.

## Image interface

The same variables `mlp1-toolchain` exports, under `/opt/xylem-toolchain`:

```text
CROSS_TRIPLE=aarch64-buildroot-linux-gnu
CROSS_COMPILE=aarch64-buildroot-linux-gnu-
TOOLCHAIN_DIR=/opt/xylem-toolchain
SYSROOT=/opt/xylem-toolchain/aarch64-buildroot-linux-gnu/sysroot
CC, CXX, AR, AS, LD, NM, OBJCOPY, RANLIB, STRIP, READELF
CMAKE_TOOLCHAIN_FILE=/opt/xylem-toolchain/Toolchain.cmake
PKG_CONFIG_SYSROOT_DIR=/opt/xylem-toolchain/aarch64-buildroot-linux-gnu/sysroot
UMRK_TARGET_OS=xylem
```

`UNION_PLATFORM` isn't set: one SDK serves every RK356x board xylem runs on
(the MLP1 and the RG DS Plus), so the board is the build's choice, not the
image's. `pkg-config` and `wayland-scanner` on `PATH` are the SDK's own.

Repos that run `mlp1-toolchain`'s image take the image as a variable, so
this one can stand in. Pin it by ID, and give the build its own output
folder: Jawaka's `make mlp1` doesn't pass `BUILD` into the container, so
call its port makefile directly or it overwrites the stock build in
`build/mlp1`:

```sh
image="$(docker image inspect --format '{{.Id}}' \
  ghcr.io/utility-muffin-research-kitchen/xylem-toolchain:local)"
docker run --rm -v "$PWD/..":/workspace -w /workspace/Jawaka "$image" \
  make -f ports/mlp1/Makefile all BUILD=build/xylem
```

`PLATFORM=mlp1` is still stock's backend (`device_mlp1.c`): this builds it
against xylem's libraries, it doesn't port it.

## Building it

```sh
make sdk     # the SDK tarball into dist/ (28 minutes on a 15-core M-series Mac)
make image   # ghcr.io/utility-muffin-research-kitchen/xylem-toolchain:local
make smoke   # link the smoke program against every library and check it
```

`make sdk` builds in the Docker volume `xylem-toolchain-sdk-<arch>` with the
`xylem-toolchain-builder` image (the Debian xylem builds on, pinned by
digest). `make sdk-config` merges and checks the configuration only, and
`make sdk-make T=<target>` runs any Buildroot target in that tree.

`make check-xylem` compares `configs/xylem-base.fragment` and the Buildroot
version with xylem at the commit in `xylem.ref`, through `gh` (xylem is
private). Moving to a newer xylem is: change `XYLEM_REF`, run
`make check-xylem`, copy over any lines it reports, `make sdk image smoke`.

## Smoke tests

`make smoke` builds three programs in `examples/smoke/`, checks them, and
runs them:

- a C program that links every C library in the set and calls each one
  (versions, an in-memory SQLite JSON query, curl's TLS backend, a SHA-512
  `crypt`, inih, a zlib round trip, the Wayland half of `SDL_syswm.h`);
- a C++ one against libstdc++, threads and fmt;
- a CMake one through the image's `Toolchain.cmake`, SDL2's own CMake
  package, CMake's Vulkan finder and `pkg_check_modules`.

`scripts/verify-binary.sh` checks each binary: the loader must be
`/lib/ld-linux-aarch64.so.1` and every `NEEDED` library must be in the
sysroot; it prints the newest `GLIBC_` and `GLIBCXX_` versions used. The run
goes through the sysroot's own loader and libraries, so it needs an arm64
host (or qemu-user).

`make smoke-leaf` builds real Leaf code against the image from clean
`git archive` exports of the sibling checkouts (never the checkouts
themselves), into `../.worktrees/xylem-toolchain-smoke/`: every Catastrophe
example through its Linux target, and Jawaka's `PLATFORM=mlp1` build. Then
it runs `verify-binary.sh` on each binary.

Results on 2026-11-25 (image `sha256:940ff77a2f79…`, Jawaka `3a87162`,
Catastrophe `a32c248`): everything builds and passes, with no change to
either repository. Catastrophe's 26 warnings are the same as on
`mlp1-toolchain`. Jawaka has two more than on `mlp1-toolchain`, both GCC
15 `-Wformat-truncation` on copies that are already bounded
(`internal/db/db.c` 2737, `internal/platform/game_display.h` 122). No
binary needs a glibc symbol newer than 2.38.

Catastrophe's Linux target calls `cc` by name, so `smoke-leaf.sh` puts a
`cc` script on `PATH` that runs `$CC`. A symlink doesn't work: Buildroot's
compiler wrapper finds the real compiler from the name it was called by.

## Matching the image

The SDK is only right while xylem's image builds the same libraries the same
way. Versions follow from the shared Buildroot. These options change what a
library exports or what its headers say, so the image has to make the same
choice:

- SDL2's video back ends (they're recorded in `SDL_config.h`, which
  `SDL_syswm.h` reads). Buildroot's recipe turns Vulkan, PulseAudio, dbus,
  HIDAPI and the dummy video driver off.
- libxcrypt's compat API (`br2-external/external.mk`).
- C++ in the toolchain.

SDL2's PulseAudio back end is the image's choice alone: SDL loads it at run
time, and nothing in SDL's headers depends on it.

## CI

Nothing runs on a push or a pull request: a cold SDK build takes too long
to gate every change. Two workflows run by hand, and one of them on tags:

- **Build SDK** (`.github/workflows/build-sdk.yml`): the SDK for
  `linux/amd64` and `linux/arm64`, each on its own runner, then an image from
  it and `make smoke` in that image (the amd64 runner runs the aarch64 smoke
  programs through QEMU). The tarballs and manifests are kept as artifacts
  for 14 days, and each job's summary lists its versions. Run it to check a
  change without publishing anything.
- **Publish image** (`.github/workflows/publish.yml`): by hand, or when a
  `v*` tag is pushed. It runs Build SDK, then builds one multi-platform image
  from both tarballs and pushes it to
  `ghcr.io/utility-muffin-research-kitchen/xylem-toolchain`, tagged with the
  branch and the commit (`sha-…`), and for a tag with its version and
  `latest`. The job summary gives the digest and how to turn it into the
  image ID Leaf pins.

`make smoke-leaf` stays local: it needs the sibling checkouts.
