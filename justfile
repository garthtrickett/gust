set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
import 'justfile-reports'
import 'justfile-step51'
import 'justfile-step44'
import 'justfile-step45'

default:
    just --list

# Canonical build graph stays in Make.
gust:
    make gust

test:
    make test

bootstrap:
    make bootstrap

make-target target:
    make "{{target}}"

# Rust test helpers.
gtl:
    RUST_LOG=debug cargo test test -- --nocapture --test-threads=1 > to.log 2>&1
    echo "📝 All tests run. Output written to to.log"

gt-one name:
    RUST_LOG=debug cargo test "{{name}}" -- --nocapture > to.log 2>&1
    echo "📝 Test '{{name}}' run. Output written to to.log"

# Focused self-hosted Gust workflows use the shared script.
gt-one-gst file:
    bash scripts/run-gust-file.sh "{{file}}"

guard file:
    bash scripts/run-gust-file.sh "{{file}}"

guard-step51-hashmap-get-value:
    just guard compiler/typechecker_hashmap_get_value_provenance_test_entry.gst

guard-step51-hashmap-get-value-field:
    just guard compiler/typechecker_hashmap_get_value_field_provenance_test_entry.gst

guard-step51-non-launder-hashmap-get-value:
    just guard compiler/typechecker_non_laundering_hashmap_get_value_test_entry.gst

guard-step51-non-launder-hashmap-get-value-field:
    just guard compiler/typechecker_non_laundering_hashmap_get_value_field_test_entry.gst

# Command-only Step 4.4/4.5 guard implementations live in imported justfile-step44/justfile-step45.

# Report aliases stay informational; Makefile policy guards keep reports out of make test.
report-step51:
 just report_step51_status_matrix
 just report_step51_deferred_unsafe_semantics_status

report-step52:
 just report_step52_status_matrix
 just report_step52_final_validation

make-test-guards:
    #!/usr/bin/env bash
    set -euo pipefail
    make gust
    guards=(
      guard_step45_safe_subscript_write_enforcement
      guard_step51_basic_unsafe_enforcement
      guard_step51_extern_func_parser_metadata
      guard_step51_extern_func_call_enforcement
      guard_step51_layout_metadata_defaults
      guard_step51_layout_ffi_policy_helpers
      guard_step51_layout_ffi_signature_helpers
      guard_step51_sandbox_policy_defaults
      guard_step51_address_origin_metadata
      guard_step51_expression_provenance_carrier
      guard_step51_safe_constructor_provenance
      guard_step51_selector_safe_constructor_provenance
      guard_step51_container_safe_constructor_provenance
      guard_step51_container_method_provenance
      guard_step51_arena_write_provenance
      guard_step51_container_getref_provenance
      guard_step51_hashmap_get_value_provenance
      guard_step51_hashmap_get_value_field_provenance
      guard_step51_std_vector_getref_provenance
      guard_step51_std_hashmap_getref_provenance
      guard_step51_std_hashmap_getref_selector_alias_provenance
      guard_step51_std_vector_getref_selector_alias_provenance
      guard_step51_reference_selector_alias_provenance
      guard_step51_variable_provenance_bindings
      guard_step51_return_provenance_capture
      guard_step51_function_call_provenance
      guard_step51_aggregate_field_provenance
      guard_step51_container_provenance
      guard_step51_non_laundering_return_enforcement
      guard_step51_non_laundering_binding_enforcement
      guard_step51_non_laundering_call_enforcement
      guard_step51_non_laundering_field_enforcement
      guard_step51_non_laundering_container_enforcement
      guard_step51_non_laundering_container_method_enforcement
      guard_step51_non_laundering_arena_write_enforcement
      guard_step51_non_laundering_reference_selector_enforcement
      guard_step51_non_laundering_hashmap_get_value_enforcement
      guard_step51_non_laundering_hashmap_get_value_field_enforcement
      guard_step51_report_only_lanes_not_in_test
      guard_step52_report_only_lanes_not_in_test
      guard_step52_no_post_closure_report_churn
      guard_parser_high_level_raw_casts
      guard_step44_low_risk_entry_raw_casts
      guard_step44_typechecker_aux_raw_casts
      guard_step44_typechecker_types_raw_casts
      guard_step44_codegen_initializer_raw_casts
      guard_step44_typechecker_early_raw_casts
      guard_step44_typechecker_methods_raw_casts
      guard_step44_typechecker_pool_graph_raw_casts
      guard_step44_typechecker_call_validation_raw_casts
      guard_step44_typechecker_generic_helpers_raw_casts
      guard_step44_typechecker_template_registration_raw_casts
      guard_step44_typechecker_env_registration_raw_casts
      guard_step44_typechecker_brand_helpers_raw_casts
      guard_step44_typechecker_function_checks_raw_casts
      guard_step44_typechecker_statement_traversal_raw_casts
      guard_step44_codegen_early_helpers_raw_casts
      guard_step44_codegen_dispatch_methods_raw_casts
      guard_step44_codegen_pool_graph_std_raw_casts
      guard_step44_codegen_std_alloc_helpers_raw_casts
      guard_step44_codegen_runtime_tail_raw_casts
      guard_step44_codegen_statement_emit_raw_casts
      guard_step44_codegen_program_passes_raw_casts
      guard_step44_no_high_level_raw_collection_casts
    )
    for guard_name in "${guards[@]}"; do
      just "$guard_name"
    done

make-test-suite:
    just make-test-guards
    mkdir -p build
    echo "⚙️  Compiling native Gust test runner..."
    ./gust tests/test_runner.gst | grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > build/test_runner.c
    cat src/runtime.c build/test_runner.c > build/test_runner_final.c
    CC_BIN="${CC:-cc}"; CFLAGS_VAL="${CFLAGS:--O2 -Wall -pthread}"; INCLUDES_VAL="${INCLUDES:--Isrc}"; "$CC_BIN" $CFLAGS_VAL $INCLUDES_VAL build/test_runner_final.c -o build/test_runner_bin
    echo "🏃 Running native Gust test runner..."
    ./build/test_runner_bin
    make test_tree_sitter

check:
    make
    make test
    make bootstrap
