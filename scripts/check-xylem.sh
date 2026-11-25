#!/usr/bin/env bash
# Check that configs/xylem-base.fragment still holds xylem's toolchain lines
# and that xylem still pins the same Buildroot. Reads xylem's files at a ref
# through gh, since xylem is a private repository.
set -euo pipefail

ref=${1:?usage: check-xylem.sh <xylem-ref>}
root=$(cd "$(dirname "$0")/.." && pwd)
repo=Utility-Muffin-Research-Kitchen/xylem
. "$root/xylem.ref"

fetch() {
	gh api "repos/$repo/contents/$1?ref=$ref" --jq .content | base64 --decode
}

# The lines that decide the toolchain; BR2_CCACHE is left out on purpose
pattern='^BR2_(aarch64|cortex_|ARM_FPU|ARM_INSTRUCTIONS|TOOLCHAIN_|GCC_|KERNEL_HEADERS|BINUTILS|GLIBC|GDB|ENABLE_LOCALE|OPTIMIZE|SSP_|RELRO|FORTIFY|PIC_PIE)'
theirs=$(fetch buildroot/configs/rgdsplus_defconfig | grep -E "$pattern" | sort)
ours=$(grep -E "$pattern" "$root/configs/xylem-base.fragment" | sort)

status=0
if [ "$theirs" != "$ours" ]; then
	echo "toolchain lines differ from xylem at $ref (< xylem, > here):" >&2
	diff <(echo "$theirs") <(echo "$ours") >&2 || true
	status=1
fi

their_br=$(fetch scripts/build.sh | sed -n 's/^BUILDROOT_VERSION=//p')
if [ "$their_br" != "$BUILDROOT_VERSION" ]; then
	echo "xylem at $ref builds Buildroot $their_br, this SDK $BUILDROOT_VERSION" >&2
	status=1
fi

[ "$status" -eq 0 ] && echo "toolchain lines and Buildroot $BUILDROOT_VERSION match xylem at $ref"
exit "$status"
