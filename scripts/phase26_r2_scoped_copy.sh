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
test -x ./gust || { echo 'R2 Gust build artifact is not executable' >&2; exit 1; }
test -x build/gust-native-backend || {
    echo 'R2 native worker build artifact is not executable' >&2
    exit 1
}
source_cases=(four_arg local_five_arg caller_five_arg zero_length renamed_types caller_distinct_arenas two_callers distinct_formals_same_arena)
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

# A source-produced recursive direct-call graph still contains the genuine
# typed collection opcodes. It must fail at the current worker graph proof,
# before package admission or any generated program can run.
recursive_dir="$scratch/producer-recursive_caller"
mkdir -p "$recursive_dir"
recursive_source="$PWD/tests/cranelift/phase26_r2_scoped_recursive_caller.gst"
if GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
   GUST_NATIVE_BACKEND_DRIVER="$PWD/build/gust-native-backend" \
   GUST_NATIVE_KEEP_OBJECTS="$PWD/$recursive_dir/keep" \
       ./gust --backend cranelift -o "$recursive_dir/never-execute" \
       "$recursive_source" >"$recursive_dir/compile.stdout" \
       2>"$recursive_dir/compile.stderr"; then
    recursive_status=0
else
    recursive_status=$?
fi
test "$recursive_status" -gt 0 && test "$recursive_status" -lt 128
test ! -e "$recursive_dir/never-execute" && test ! -L "$recursive_dir/never-execute"
rg -F 'stage=canonical_mir_validation kind=invalid_canonical_mir' \
    "$recursive_dir/compile.stderr" >/dev/null
rg -F 'collection caller graph is recursive' \
    "$recursive_dir/compile.stderr" >/dev/null
python3 scripts/phase26_r2_source_projection.py recursive_caller \
    "$recursive_dir/keep/program.mir.bundle"

# The typed producer emits both hostile caller histories. The current worker
# must reject the field write and copied alias before package admission; only
# canonical bytes are retained, and neither generated program is executed.
for case in forged_len copied_alias; do
    case_dir="$scratch/producer-$case"
    source="$PWD/tests/cranelift/phase26_r2_scoped_caller_${case}_never_execute.gst"
    mkdir -p "$case_dir"
    if GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
       GUST_NATIVE_BACKEND_DRIVER="$PWD/build/gust-native-backend" \
       GUST_NATIVE_KEEP_OBJECTS="$PWD/$case_dir/keep" \
           ./gust --backend cranelift -o "$case_dir/never-execute" "$source" \
           >"$case_dir/compile.stdout" 2>"$case_dir/compile.stderr"; then
        status=0
    else
        status=$?
    fi
    test "$status" -gt 0 && test "$status" -lt 128
    test ! -e "$case_dir/never-execute" && test ! -L "$case_dir/never-execute"
    rg -F 'stage=canonical_mir_validation kind=invalid_canonical_mir' \
        "$case_dir/compile.stderr" >/dev/null
    if test "$case" = forged_len; then
        expected='collection caller has unsupported control or aliasing'
    else
        expected='collection caller local has an unproved initializer'
    fi
    rg -F "$expected" "$case_dir/compile.stderr" >/dev/null
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
    if GUST_NATIVE_BACKEND_DRIVER="$PWD/build/gust-native-backend" \
       ./gust --backend cranelift -o "$case_dir/program" "$source" \
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
run_family fallible_cleanup full_program::fallible_automatic_cleanup_tests \
    full_program::fallible_automatic_cleanup_tests::automatic_exit_requires_exact_owner_storage_and_no_bypassing_control \
    full_program::fallible_automatic_cleanup_tests::reserved_region_symbols_reject_absent_and_other_policies \
    full_program::fallible_automatic_cleanup_tests::reserved_constructor_rejects_untagged_and_unbound_calls \
    full_program::fallible_automatic_cleanup_tests::actual_tag9_only_source_requires_unique_unsafe_reachability \
    full_program::fallible_automatic_cleanup_tests::flat_owner_cleanup_rejects_inline_callee_substitution
run_family scoped_copy scoped_byte_copy::tests \
    scoped_byte_copy::tests::typed_byte_collection_requires_the_existing_native_route_and_layout \
    scoped_byte_copy::tests::historical_scoped_candidate_cannot_skip_executable_collection_contract \
    scoped_byte_copy::tests::typed_four_argument_scoped_candidate_passes_the_whole_parser \
    scoped_byte_copy::tests::typed_caller_borrowed_input_and_fifth_scalar_pass_the_whole_parser \
    scoped_byte_copy::tests::actual_borrowed_collection_operation_and_byte_type_mutants_refuse \
    scoped_byte_copy::tests::scoped_collection_opcode_cannot_be_replaced_by_name_dispatch \
    scoped_byte_copy::tests::current_intrinsic_unknown_version_and_opcode_fail_closed \
    scoped_byte_copy::tests::typed_local_input_and_fifth_scalar_pass_the_whole_parser \
    scoped_byte_copy::tests::actual_scoped_owner_and_result_type_names_are_not_authority \
    scoped_byte_copy::tests::actual_scoped_copy_rejects_wrong_write_read_and_publication_bindings \
    scoped_byte_copy::tests::source_produced_renamed_owner_and_result_have_the_same_scoped_proof \
    scoped_byte_copy::tests::typed_no_defer_scoped_candidate_lowers_to_native_object \
    scoped_byte_copy::tests::actual_intrinsic_producer_mutations_reject_at_expected_owners \
    scoped_byte_copy::tests::current_intrinsic_scope_rejects_inline_native_and_cleanup_dispatch \
    scoped_byte_copy::tests::historical_preintrinsic_mutation_corpus_cannot_be_upgraded_by_metadata \
    scoped_byte_copy::tests::current_intrinsic_scope_rejects_shared_native_call_before_recursive_walks
run_family collection_provenance collection_provenance::tests \
    collection_provenance::tests::actual_source_produced_intrinsic_caller_has_closed_history \
    collection_provenance::tests::caller_return_evaluates_scoped_call_before_deferred_arena_free \
    collection_provenance::tests::source_produced_caller_metadata_write_and_copy_alias_refuse_at_provenance \
    collection_provenance::tests::two_source_produced_callers_with_different_histories_are_both_checked \
    collection_provenance::tests::orphan_executable_operation_has_no_caller_or_scoped_authority \
    collection_provenance::tests::source_produced_recursive_caller_graph_refuses_before_storage_substitution \
    collection_provenance::tests::caller_field_alias_cannot_replace_the_direct_borrow \
    collection_provenance::tests::distinct_live_input_and_output_arenas_preserve_closed_history \
    collection_provenance::tests::distinct_formal_brands_can_substitute_the_same_live_arena \
    collection_provenance::tests::source_produced_collection_identities_bind_each_operation_and_arena \
    collection_provenance::tests::actual_caller_rejects_early_free_and_alternate_callee \
    collection_provenance::tests::scoped_direct_callee_cannot_switch_to_inline_dispatch \
    collection_provenance::tests::caller_scalar_read_must_match_its_reaching_declaration_type
run_family collection_work_budget full_program::collection_intrinsic_work_budget_tests \
    full_program::collection_intrinsic_work_budget_tests::layout_resolution_rejects_multiplied_work_before_orphan_walk \
    full_program::collection_intrinsic_work_budget_tests::nonbyte_element_refuses_before_recursive_layout_resolution
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

# The signed caller fixture must publish the actual copied bytes, then free
# its private region exactly once. The inverted byte oracle must fail at the
# byte assertion. GDB is an approved test-only CI dependency.
python3 scripts/phase26_r2_byte_observer.py \
    "$scratch/signed-0" "$scratch/byte-observer" \
    >"$scratch/byte-observer.stdout" 2>"$scratch/byte-observer.stderr"

echo 'Phase 26 R2 scoped byte-copy test-profile admission, runtime and default-deny passed.'
