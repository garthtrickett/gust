#!/usr/bin/env bash
set -euo pipefail

# Build the optional Phase 26 native component from the exact upstream source
# archive. This script does not install a library or create a trusted package:
# signing identity, release epoch, and withdrawal policy are release inputs.
if [[ $# != 2 ]]; then
    echo "usage: $0 zlib-1.3.2.tar.gz NEW_OUTPUT_DIRECTORY" >&2
    exit 2
fi
archive=$(realpath "$1")
output=$(realpath -m "$2")
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
expected=bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16
actual=$(sha256sum "$archive" | cut -d' ' -f1)
if [[ $actual != "$expected" ]]; then
    echo "Phase 26 zlib source archive digest mismatch" >&2
    exit 1
fi
if [[ $(uname -m) != x86_64 || -e $output ]]; then
    echo "Phase 26 zlib build requires x86_64 and a new output directory" >&2
    exit 1
fi
mkdir -m 700 "$output"
tar -xzf "$archive" -C "$output"
source="$output/zlib-1.3.2"
package="$output/package"
mkdir -m 700 "$package"
cp "$archive" "$package/zlib-1.3.2.tar.gz"
cp "$repo/compiler/experiments/cranelift/ffi-zlib/gust_zlib_adapter.c" "$package/"
cp "$repo/compiler/experiments/cranelift/ffi-zlib/gust_zlib_adapter.h" "$package/"
cp "$source/zlib.h" "$source/zconf.h" "$package/"
cp "$source/LICENSE" "$package/zlib-LICENSE"

compiler=/usr/bin/cc
archiver=/usr/bin/ar
indexer=/usr/bin/ranlib
# Only the static compression/decompression dependency closure is linked. The
# gzip file API has no role in this package and would add file I/O symbols.
objects=(adler32 crc32 deflate infback inffast inflate inftrees trees zutil \
         compress uncompr)
flags=(-O2 -std=c11 -fno-common -Werror=implicit-function-declaration -I "$source")
object_paths=()
for name in "${objects[@]}"; do
    "$compiler" "${flags[@]}" -c "$source/$name.c" -o "$output/$name.o"
    object_paths+=("$output/$name.o")
done
"$archiver" rcD "$package/libz.a" "${object_paths[@]}"
"$indexer" -D "$package/libz.a"
"$compiler" -O2 -std=c11 -Wall -Wextra -Werror -fno-common \
    -I "$source" -I "$package" -c "$package/gust_zlib_adapter.c" \
    -o "$package/gust_zlib_adapter.o"

{
    printf 'format: gust.phase26.r3.build_options.v1\n'
    printf 'target: x86_64-unknown-linux-gnu\n'
    printf 'upstream_release: zlib-1.3.2\n'
    printf 'source_sha256: %s\n' "$expected"
    printf 'compiler: %s\n' "$($compiler --version | sed -n '1p')"
    printf 'compiler_sha256: %s\n' "$(sha256sum "$(realpath "$compiler")" | cut -d' ' -f1)"
    printf 'archiver: %s\n' "$($archiver --version | sed -n '1p')"
    printf 'archiver_sha256: %s\n' "$(sha256sum "$(realpath "$archiver")" | cut -d' ' -f1)"
    printf 'indexer_sha256: %s\n' "$(sha256sum "$(realpath "$indexer")" | cut -d' ' -f1)"
    printf 'zlib_flags: -O2 -std=c11 -fno-common -Werror=implicit-function-declaration -I <pinned-source>\n'
    printf 'adapter_flags: -O2 -std=c11 -Wall -Wextra -Werror -fno-common\n'
    printf 'archive_flags: ar rcD; ranlib -D\n'
    printf 'zlib_objects: %s\n' "${objects[*]}"
} > "$package/build-options.txt"

"$compiler" -O2 -std=c11 -Wall -Wextra -Werror \
    -I "$package" "$repo/tests/phase26_r3_zlib_adapter.c" \
    "$package/gust_zlib_adapter.o" "$package/libz.a" \
    -o "$output/phase26-r3-adapter-test"
"$output/phase26-r3-adapter-test"
sha256sum "$package"/*
