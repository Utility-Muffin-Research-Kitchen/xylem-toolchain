#!/bin/sh
# Print what the SDK in $1 (a Buildroot host directory) contains: the
# toolchain's versions and every library's pkg-config version. Runs in the
# builder container after `make sdk`, and in the published image
# (`sdk-manifest.sh "$TOOLCHAIN_DIR"`), so the two can be compared.
set -eu

host=${1:?usage: sdk-manifest.sh <sdk-dir>}
tuple=aarch64-buildroot-linux-gnu
sysroot=$host/$tuple/sysroot
here=$(dirname "$0")

ref_file=/src/xylem.ref
[ -f "$ref_file" ] || ref_file=$here/../xylem.ref
[ -f "$ref_file" ] || ref_file=$host/share/xylem-toolchain/xylem.ref
if [ -f "$ref_file" ]; then
	grep -E '^(XYLEM_REF|BUILDROOT_VERSION)=' "$ref_file" | tr 'A-Z' 'a-z' | sed 's/^/source./'
fi

echo "sdk.tuple=$tuple"
echo "sdk.gcc=$("$host/bin/$tuple-gcc" -dumpfullversion)"
echo "sdk.binutils=$("$host/bin/$tuple-ld" --version | head -n 1 | sed 's/.* //')"

macro() {
	printf '#include <%s>\n%s\n' "$1" "$2" |
		"$host/bin/$tuple-gcc" -E -P - | tail -n 1 | tr -d ' '
}
echo "sdk.glibc=$(macro features.h __GLIBC__).$(macro features.h __GLIBC_MINOR__)"
code=$(macro linux/version.h LINUX_VERSION_CODE)
echo "sdk.kernel_headers=$((code >> 16)).$(((code >> 8) & 255)).$((code & 255))"
echo "sdk.libstdcxx=$(ls "$sysroot"/usr/lib/libstdc++.so.6.* 2>/dev/null | grep -v '\.py$' | sed 's|.*/libstdc++.so.||' | head -n 1)"

export PKG_CONFIG_SYSROOT_DIR="$sysroot"
export PKG_CONFIG_LIBDIR="$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig"
pkgconf=$host/bin/pkg-config
for module in \
	sdl2 SDL2_image SDL2_ttf SDL2_mixer \
	egl glesv2 gbm libdrm vulkan \
	wayland-client wayland-egl wayland-scanner wayland-protocols xkbcommon \
	alsa libpulse libpulse-simple libudev \
	sqlite3 freetype2 harfbuzz libpng libjpeg zlib json-c \
	libcurl openssl libcrypt icu-uc fmt inih pixman-1
do
	version=$("$pkgconf" --modversion "$module" 2>/dev/null || echo missing)
	echo "pkg.$module=$version"
done

# SDL2's back ends, as its public config header records them
for define in SDL_VIDEO_DRIVER_WAYLAND SDL_VIDEO_DRIVER_KMSDRM SDL_VIDEO_DRIVER_X11 \
	SDL_VIDEO_OPENGL_ES2 SDL_VIDEO_OPENGL_EGL SDL_VIDEO_VULKAN \
	SDL_AUDIO_DRIVER_ALSA SDL_AUDIO_DRIVER_PULSEAUDIO SDL_UDEV_DYNAMIC
do
	if grep -q "^#define $define " "$sysroot/usr/include/SDL2/SDL_config.h"; then
		echo "sdl2.$define=on"
	else
		echo "sdl2.$define=off"
	fi
done

if [ -e "$sysroot/usr/lib/libcrypt.so.1" ]; then
	echo "libxcrypt.compat=libcrypt.so.1"
else
	echo "libxcrypt.compat=none"
fi
