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
`configs/xylem-base.fragment`.

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

To use it where a build takes `mlp1-toolchain`'s image, pass this one's ID:

```sh
image="$(docker image inspect --format '{{.Id}}' \
  ghcr.io/utility-muffin-research-kitchen/xylem-toolchain:local)"
make -C ../Jawaka mlp1 MLP1_TOOLCHAIN_IMAGE="$image" BUILD=build/xylem
```

## Building it

```sh
make sdk     # the SDK tarball into dist/ (about an hour the first time)
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

## Smoke test

`examples/smoke/` links one C program against every C library in the set and
a C++ one against libstdc++ and fmt. `make smoke` builds them and runs
`scripts/verify-binary.sh` on each: the loader must be
`/lib/ld-linux-aarch64.so.1` and every `NEEDED` library must be in the
sysroot; it prints the newest `GLIBC_` and `GLIBCXX_` versions used. On an
arm64 host, `make -C examples/smoke run` inside the image also runs them
through the sysroot's own loader.

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

None yet. `mlp1-toolchain`'s two workflows (SDK artifacts for `linux/amd64`
and `linux/arm64`, then a multi-platform GHCR image) are the pattern to copy.
