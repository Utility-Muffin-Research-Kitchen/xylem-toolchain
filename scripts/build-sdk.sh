#!/bin/sh
# Runs inside the builder container (docker/Dockerfile). /src is this
# repository, read-only; /work is a Docker volume, because Buildroot needs a
# case-sensitive filesystem and the Mac's isn't.
#
#   build-sdk.sh            configure, build the SDK, package it into /work/dist
#   build-sdk.sh config     configure and check the merged config only
#   build-sdk.sh <targets>  run Buildroot make targets in the configured tree
set -eu

. /src/xylem.ref
SDK_ARCH=${SDK_ARCH:?}
BUILDROOT=/work/buildroot-$BUILDROOT_VERSION
OUTPUT=/work/output
DIST=/work/dist
export BR2_DL_DIR=/work/dl
TUPLE=aarch64-buildroot-linux-gnu

mkdir -p "$BR2_DL_DIR" "$OUTPUT" "$DIST"
if [ ! -d "$BUILDROOT" ]; then
	tarball=$BR2_DL_DIR/buildroot-$BUILDROOT_VERSION.tar.xz
	[ -f "$tarball" ] || wget -q -O "$tarball" "https://buildroot.org/downloads/buildroot-$BUILDROOT_VERSION.tar.xz"
	echo "$BUILDROOT_SHA256  $tarball" | sha256sum -c -
	tar -C /work -xf "$tarball"
fi

configure() {
	cat /src/configs/xylem-base.fragment /src/configs/leaf-sdk.fragment > "$OUTPUT/xylem_sdk_defconfig"
	make -C "$BUILDROOT" O="$OUTPUT" BR2_EXTERNAL=/src/br2-external \
		BR2_DEFCONFIG="$OUTPUT/xylem_sdk_defconfig" defconfig >/dev/null
	# Every setting line has to survive into .config, "is not set" lines too
	grep -h -E '^(BR2_[A-Za-z0-9_]+=|# BR2_[A-Za-z0-9_]+ is not set)' \
		/src/configs/xylem-base.fragment /src/configs/leaf-sdk.fragment |
	while IFS= read -r line; do
		grep -qxF "$line" "$OUTPUT/.config" || echo "$line"
	done > "$OUTPUT/.config-missing"
	if [ -s "$OUTPUT/.config-missing" ]; then
		echo "build-sdk: these lines didn't make it into the final .config:" >&2
		cat "$OUTPUT/.config-missing" >&2
		exit 1
	fi
	echo "build-sdk: configuration checked ($(grep -c '=y$' "$OUTPUT/.config") options on)"
}

case "${1:-all}" in
config)
	configure
	exit 0
	;;
all)
	configure
	;;
*)
	make -C "$OUTPUT" "$@"
	exit 0
	;;
esac

make -C "$OUTPUT" sdk

host=$OUTPUT/host
[ -x "$host/bin/$TUPLE-gcc" ] || { echo "build-sdk: no cross compiler in $host" >&2; exit 1; }

sh /src/scripts/sdk-manifest.sh "$host" > "$DIST/xylem-sdk-linux-$SDK_ARCH.txt"
cat "$DIST/xylem-sdk-linux-$SDK_ARCH.txt"
tar -czf "$DIST/xylem-sdk-linux-$SDK_ARCH.tar.gz.part" -C "$host" .
mv "$DIST/xylem-sdk-linux-$SDK_ARCH.tar.gz.part" "$DIST/xylem-sdk-linux-$SDK_ARCH.tar.gz"
ls -l "$DIST"
