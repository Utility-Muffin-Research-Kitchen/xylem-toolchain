#!/bin/sh
# What an aarch64 binary built with the xylem SDK asks of the device: its
# loader, the newest glibc and libstdc++ symbol versions it uses, and each
# NEEDED library with whether the SDK's sysroot has it. Fails if the loader
# isn't xylem's or a NEEDED library isn't in the sysroot.
set -eu

bin=${1:?usage: verify-binary.sh <elf>}
readelf=${READELF:-aarch64-buildroot-linux-gnu-readelf}
sysroot=${SYSROOT:?SYSROOT unset}
status=0

interp=$("$readelf" -l "$bin" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')
echo "$bin"
echo "  interpreter: ${interp:-none (static)}"
if [ -n "$interp" ] && [ "$interp" != /lib/ld-linux-aarch64.so.1 ]; then
	echo "  unexpected interpreter" >&2
	status=1
fi

newest() {
	"$readelf" -V --wide "$bin" | grep -o "$1_[0-9.]*" | sed "s/$1_//" | sort -t. -k1,1n -k2,2n -k3,3n -u | tail -n 1
}
echo "  newest GLIBC_: $(newest GLIBC)"
cxx=$(newest GLIBCXX)
[ -z "$cxx" ] || echo "  newest GLIBCXX_: $cxx"

for lib in $("$readelf" -d "$bin" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'); do
	if [ -e "$sysroot/lib/$lib" ] || [ -e "$sysroot/usr/lib/$lib" ]; then
		echo "  needs $lib"
	else
		echo "  needs $lib: NOT IN THE SYSROOT" >&2
		status=1
	fi
done
exit "$status"
