#!/usr/bin/env bash
set -Eeuo pipefail

# Optional foreign-component qualification. The production verifier retains
# its empty key/registry until a release signing identity is designated.
test "$(uname -s)" = Linux
test "$(uname -m)" = x86_64
test -x ./gust
test -x build/gust-native-backend
test -s build/gust-runtime-package.a

scratch=build/guards/phase26_r3_zlib_adapter
rm -rf "$scratch"
mkdir -p "$scratch/linked"
report_failure() {
    local status=$?
    find "$scratch" -maxdepth 2 -type f \( -name '*.stderr' -o -name '*.stdout' \) \
        -print -exec tail -n 25 {} \; >&2
    exit "$status"
}
trap report_failure ERR

archive="$scratch/zlib-1.3.2.tar.gz"
curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
    --retry 3 --max-time 90 https://zlib.net/zlib-1.3.2.tar.gz \
    --output "$archive"
printf '%s  %s\n' \
    bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16 \
    "$archive" | sha256sum -c -
bash scripts/phase26_r3_zlib_adapter.sh "$archive" "$scratch/build" \
    > "$scratch/adapter.stdout" 2> "$scratch/adapter.stderr"
rg -F 'phase26_r3_zlib_adapter: PASS' "$scratch/adapter.stdout" >/dev/null

for case in compress decompress empty_decompress; do
    case_dir="$scratch/source-$case"
    mkdir -p "$case_dir"
    source="$PWD/tests/cranelift/phase26_r3_zlib_$case.gst"
    if GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
       GUST_NATIVE_BACKEND_DRIVER="$PWD/build/gust-native-backend" \
       GUST_NATIVE_KEEP_OBJECTS="$PWD/$case_dir/keep" \
           ./gust --backend cranelift -o "$case_dir/never-execute" "$source" \
           > "$case_dir/compile.stdout" 2> "$case_dir/compile.stderr"; then
        status=0
    else
        status=$?
    fi
    test "$status" -gt 0 && test "$status" -lt 128
    test ! -e "$case_dir/never-execute" && test ! -L "$case_dir/never-execute"
    rg -F 'approved native package rejected: missing package' \
        "$case_dir/compile.stderr" >/dev/null
    python3 scripts/phase26_r3_source_projection.py "$case" \
        "$case_dir/keep/program.mir.bundle"
done

export GUST_R3_PACKAGE_DIR="$PWD/$scratch/build/package"
export GUST_R3_LINKED_EXECUTABLE_DIR="$PWD/$scratch/linked"
export GUST_R2_RUNTIME_ARCHIVE="$PWD/build/gust-runtime-package.a"
GUST_R2_RUNTIME_SHA256=$(sha256sum "$GUST_R2_RUNTIME_ARCHIVE" | cut -d' ' -f1)
export GUST_R2_RUNTIME_SHA256
cargo test --locked --manifest-path compiler/experiments/cranelift/Cargo.toml \
    approved_package::tests::actual_pinned_zlib_adapter_links_signed_scoped_calls \
    -- --ignored --exact --nocapture \
    > "$scratch/signed.stdout" 2> "$scratch/signed.stderr"
rg -F 'test approved_package::tests::actual_pinned_zlib_adapter_links_signed_scoped_calls ... ok' \
    "$scratch/signed.stdout" >/dev/null
rg -F 'test result: ok. 1 passed; 0 failed' "$scratch/signed.stdout" >/dev/null
for case in compress decompress empty_decompress; do
    test -s "$scratch/linked/$case"
    test "$(head -c 4 "$scratch/linked/$case" | od -An -tx1 | tr -d ' \n')" = 7f454c46
done
