#!/usr/bin/env bash
# Build real Leaf code with the xylem toolchain image: every Catastrophe
# example (its Linux target) and Jawaka's PLATFORM=mlp1 build (jawakad, the
# launcher, the menu, the OSD and the tools), from clean exports of each
# repository, never the checkouts themselves. Then check each binary with
# verify-binary.sh. Logs and binaries stay in $OUT.
#
#   scripts/smoke-leaf.sh [image]
#
# WORKSPACE_ROOT  the UMRK workspace (default: this repo's parent)
# JAWAKA_REF      default origin/main of $WORKSPACE_ROOT/Jawaka
# CATASTROPHE_REF default origin/main of $WORKSPACE_ROOT/Catastrophe
# OUT             default $WORKSPACE_ROOT/.worktrees/xylem-toolchain-smoke
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
ws=${WORKSPACE_ROOT:-$(cd "$root/.." && pwd)}
image=${1:-$(docker image inspect --format '{{.Id}}' ghcr.io/utility-muffin-research-kitchen/xylem-toolchain:local)}
jawaka_ref=${JAWAKA_REF:-origin/main}
catastrophe_ref=${CATASTROPHE_REF:-origin/main}
out=${OUT:-$ws/.worktrees/xylem-toolchain-smoke}

export_tree() { # repo ref dest
	rm -rf "$3"
	mkdir -p "$3"
	git -C "$1" archive "$2" | tar -x -C "$3"
	echo "$(basename "$1") $(git -C "$1" rev-parse "$2")" >> "$out/SOURCES"
}

mkdir -p "$out"
: > "$out/SOURCES"
echo "image $image" >> "$out/SOURCES"
export_tree "$ws/Jawaka" "$jawaka_ref" "$out/Jawaka"
export_tree "$ws/Catastrophe" "$catastrophe_ref" "$out/Catastrophe"
cat "$out/SOURCES"

verify=/opt/xylem-toolchain/share/xylem-toolchain/verify-binary.sh
status=0

# Catastrophe's Linux target calls `cc` by name, so put the cross compiler
# there under that name for this run
echo "== Catastrophe: make linux"
if docker run --rm -v "$out/Catastrophe":/src -w /src "$image" bash -c '
	set -e
	mkdir -p /tmp/cc && ln -sf "$CC" /tmp/cc/cc && export PATH=/tmp/cc:$PATH
	make linux
	for b in build/linux/*/*; do [ -f "$b" ] && [ -x "$b" ] && '"$verify"' "$b"; done
' > "$out/catastrophe.log" 2>&1; then
	echo "ok (log: $out/catastrophe.log)"
else
	echo "FAILED (log: $out/catastrophe.log)"
	status=1
fi

echo "== Jawaka: make -f ports/mlp1/Makefile all"
if docker run --rm \
	-v "$ws":/workspace:ro \
	-v "$out/Jawaka":/workspace/Jawaka \
	-v "$out/Catastrophe":/workspace/Catastrophe \
	-w /workspace/Jawaka "$image" bash -c '
	set -e
	make -f ports/mlp1/Makefile all BUILD=build/xylem
	for b in build/xylem/bin/*; do [ -f "$b" ] && [ -x "$b" ] && '"$verify"' "$b"; done
' > "$out/jawaka.log" 2>&1; then
	echo "ok (log: $out/jawaka.log)"
else
	echo "FAILED (log: $out/jawaka.log)"
	status=1
fi
exit "$status"
