#!/usr/bin/env bash
set -Eeuo pipefail

# This is the test-profile R2 capability gate. Production package authority
# remains empty; the signed adapter below exists only inside Rust tests.
test "$(uname -s)" = Linux
test "$(uname -m)" = x86_64
python3 scripts/phase26_r2_runtime_projection.py
python3 scripts/phase26_r2_tool_binding.py check

scratch=build/guards/phase26_r2_scoped_copy
rm -rf "$scratch"
mkdir -p "$scratch"
report_failure() {
    local status="$?"
    find "$scratch" -maxdepth 2 -type f \( -name '*.stderr' -o -name '*.stdout' \) -print \
        -exec tail -n 25 {} \; >&2
    exit "$status"
}
trap report_failure ERR

# The build job recorded this archive with the exact source and worker tools.
test -s build/gust-runtime-package.a
archive="$PWD/build/gust-runtime-package.a"
test -s "$archive"

python3 - "$archive" <<'PY'
import pathlib
import subprocess
import sys

sys.path.insert(0, "scripts")
import phase26_r2_runtime_projection as r2

make = pathlib.Path("Makefile").read_text()
marker = "PHASE25_RUNTIME_RS_EXPORTS = \\\n"
assert make.count(marker) == 1, "frozen Phase25 export root list missing"
old = make.split(marker, 1)[1].split("\n\n", 1)[0].replace("\\\n", " ").split()
expected = sorted(old + list(r2.SYMBOLS))
assert len(old) == 74 and len(expected) == 81 and len(set(expected)) == 81
listed = subprocess.check_output(["nm", "-g", "--defined-only", sys.argv[1]],
                                 text=True)
defined = [fields for line in listed.splitlines()
           if len(fields := line.split()) == 3]
legacy_data = {"os_argc", "os_argv"}
assert all((fields[2] in legacy_data and fields[1] == "B") or
           (fields[2] not in legacy_data and fields[1] == "T")
           for fields in defined), \
    "narrowed runtime archive has an unexpected definition class"
actual = sorted(fields[2] for fields in defined)
assert actual == expected, "narrowed runtime archive strong exports differ"
PY

export GUST_R2_RUNTIME_ARCHIVE="$archive"
GUST_R2_RUNTIME_SHA256="$(sha256sum "$archive" | cut -d' ' -f1)"
export GUST_R2_RUNTIME_SHA256

# The Gust producer must emit the same reviewed Program for three distinct
# source shapes. Its normal CLI remains default-denied without a production
# signing root. Only the source module path differs across checkouts.
test -x ./gust
test -x build/gust-native-backend
source_cases=(caller_five_arg zero_length renamed_types)
for case in "${source_cases[@]}"; do
    case_dir="$scratch/producer-$case"
    mkdir -p "$case_dir"
    source="$PWD/tests/cranelift/phase26_r2_scoped_$case.gst"
    if GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
       GUST_NATIVE_BACKEND_DRIVER="$PWD/build/gust-native-backend" \
       GUST_NATIVE_KEEP_OBJECTS="$PWD/$case_dir/keep" \
           ./gust --backend cranelift -o "$case_dir/production-denied" "$source" \
           >"$case_dir/compile.stdout" 2>"$case_dir/compile.stderr"; then
        status=0
    else
        status=$?
    fi
    test "$status" -ne 0
    test ! -e "$case_dir/production-denied"
    test ! -L "$case_dir/production-denied"
    rg -F 'stage=canonical_mir_validation kind=invalid_canonical_mir' \
        "$case_dir/compile.stderr" >/dev/null
    rg -F 'byte-span Call requires exact signed approved-package admission' \
        "$case_dir/compile.stderr" >/dev/null
    python3 scripts/phase26_r2_source_projection.py "$case" \
        "$case_dir/keep/program.mir.bundle"
done

# Preserve the preexisting directory compatibility route while requiring the
# new generic acquisition checks to reject scheduled or repeated consumption.
# These are source/typecheck controls; generated binaries are never run here.
resource_source_case() {
    local label="$1" source="$2" expected="$3"
    local case_dir="$scratch/resource-$label" status
    mkdir -p "$case_dir"
    if ./gust --backend cranelift -o "$case_dir/program" "$source" \
        >"$case_dir/compile.stdout" 2>"$case_dir/compile.stderr"; then
        status=0
    else
        status=$?
    fi
    if test "$expected" = success; then
        test "$status" -eq 0
        test -s "$case_dir/program"
        test "$(head -c 4 "$case_dir/program" | od -An -tx1 | tr -d ' \n')" = 7f454c46
    else
        test "$status" -gt 0 && test "$status" -lt 128
        test ! -e "$case_dir/program" && test ! -L "$case_dir/program"
        rg -F "$expected" "$case_dir/compile.stdout" >/dev/null
    fi
}
resource_source_case directory_close \
    compiler/phase20_resource_acquisition_directory_source.gst success
resource_source_case direct_release \
    tests/cranelift/phase26_r2_resource_direct_release.gst success
resource_source_case directory_move \
    tests/test_directory_leak_violation_move_open_directory.gst \
    'cannot be moved while open'
resource_source_case scheduled_consumer \
    tests/cranelift/phase26_r2_resource_scheduled_consumer.gst \
    '[ResourceAcquisitionNonLive] Resource-owned value cannot be moved'
resource_source_case consume_after_defer \
    tests/cranelift/phase26_r2_resource_consume_after_defer.gst \
    '[ResourceAcquisitionNonLive] Resource destructor cannot consume'

cargo_rust=(cargo test --release --locked --offline --jobs 2
    --manifest-path compiler/experiments/cranelift/Cargo.toml
    --target-dir "$scratch/cranelift-target")
cargo_runtime=(cargo test --release --locked --offline --jobs 2
    --manifest-path src/runtime-rs/Cargo.toml
    --target-dir "$scratch/runtime-target")

run_family() {
    local label="$1" filter="$2"
    shift 2
    "${cargo_rust[@]}" "$filter" -- --nocapture \
        >"$scratch/$label.stdout" 2>"$scratch/$label.stderr"
    for expected in "$@"; do
        rg -F "test $expected ... ok" "$scratch/$label.stdout" >/dev/null
    done
}
"${cargo_runtime[@]}" ffi_call_region::tests -- --nocapture \
    >"$scratch/runtime.stdout" 2>"$scratch/runtime.stderr"
for expected in zero_sizes_have_distinct_storage_and_no_readable_byte \
    allocation_failures_publish_no_owner \
    output_requires_acceptance_and_validated_count; do
    rg -F "test ffi_call_region::tests::$expected ... ok" \
        "$scratch/runtime.stdout" >/dev/null
done
run_family byte_spans full_program::byte_span_call_tests \
    full_program::byte_span_call_tests::direct_byte_spans_require_exact_typed_pairs_and_call_positions \
    full_program::byte_span_call_tests::new_call_reachability_rejects_shared_and_deep_bodies_before_recursion \
    full_program::byte_span_call_tests::new_call_reachability_enforces_node_and_edge_budgets_only_for_new_cohort \
    full_program::byte_span_call_tests::actual_scoped_parser_rejects_deep_unrelated_body_before_recursive_validators
run_family region_calls full_program::region_operation_call_tests \
    full_program::region_operation_call_tests::region_call_signature_is_checked_but_scoped_activation_remains_closed \
    full_program::region_operation_call_tests::imported_region_alias_binds_pure_module_selector_without_inline_override
run_family scoped_copy scoped_byte_copy::tests \
    scoped_byte_copy::tests::typed_caller_borrowed_input_and_fifth_scalar_pass_the_whole_parser \
    scoped_byte_copy::tests::actual_scoped_copy_rejects_wrong_write_read_and_publication_bindings \
    scoped_byte_copy::tests::source_produced_renamed_owner_and_result_have_the_same_scoped_proof \
    scoped_byte_copy::tests::actual_producer_canonical_mutations_reject_at_expected_owners
run_family signed_pairs approved_package::tests::signed_byte_span_pairs_match_the_actual_typed_scoped_call \
    approved_package::tests::signed_byte_span_pairs_match_the_actual_typed_scoped_call
run_family non_byte_host approved_package::tests::signed_metadata_cannot_admit_unqualified_pointer_policy \
    approved_package::tests::signed_metadata_cannot_admit_unqualified_pointer_policy
run_family signed_object approved_package::tests::actual_typed_scoped_call_admits_only_its_signed_test_object \
    approved_package::tests::actual_typed_scoped_call_admits_only_its_signed_test_object

signed_tests=(
    actual_caller_borrowed_five_argument_scoped_call_links_and_runs
    source_produced_renamed_owner_and_result_link_with_signed_test_adapter
    actual_signed_adapter_error_returns_before_output_publication
    actual_zero_length_scoped_call_links_and_runs_with_signed_test_adapter
)
for index in "${!signed_tests[@]}"; do
    test_name="approved_package::tests::${signed_tests[index]}"
    export GUST_R2_LINKED_EXECUTABLE_OUT="$PWD/$scratch/signed-$index"
    test ! -e "$GUST_R2_LINKED_EXECUTABLE_OUT"
    "${cargo_rust[@]}" "$test_name" -- --exact --ignored --nocapture \
        >"$scratch/signed-$index.stdout" 2>"$scratch/signed-$index.stderr"
    rg -F "test $test_name ... ok" "$scratch/signed-$index.stdout" >/dev/null
    test -s "$GUST_R2_LINKED_EXECUTABLE_OUT"
    test "$(head -c 4 "$GUST_R2_LINKED_EXECUTABLE_OUT" | od -An -tx1 | tr -d ' \n')" = 7f454c46
done
unset GUST_R2_LINKED_EXECUTABLE_OUT

echo 'Phase 26 R2 scoped byte-copy test-profile admission, runtime and default-deny passed.'
