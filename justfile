set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
import 'justfile-reports'
import 'justfile-step51'
import 'justfile-step44'
import 'justfile-step45'
import 'justfile-step52'

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

guard_step52_resource_use_after_move_enforcement:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2G.2 linear resource use-after-move pass/rejection behavior..."
    rg -n 'func env_report_linear_resource_use_after_move' compiler/typechecker.gst
    rg -n 'LinearResourceUseAfterMove' compiler/typechecker.gst
    rg -n -F 'env_open_linear_resource_is_moved(env, name, ctx)' compiler/typechecker.gst
    rg -n 'env_report_linear_resource_use_after_move\(env, resolved_name, expr.Identifier.span, ctx\);' compiler/typechecker.gst
    rg -n -F 'compiler/typechecker_resource_use_after_move_pass_test_entry.gst' tests/test_runner.gst
    rg -n -F 'compiler/typechecker_resource_use_after_move_rejected_test_entry.gst' tests/test_runner.gst
    just guard-positive compiler/typechecker_resource_use_after_move_pass_test_entry.gst step52_resource_use_after_move_pass
    just guard-positive compiler/typechecker_resource_use_after_move_rejected_test_entry.gst step52_resource_use_after_move_rejected
    echo "✅ Step 5.2G.2 linear resource use-after-move pass/rejection behavior guard passed."

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
      guard_step51_report_only_lanes_not_in_test
      guard_step51g_default_guard_wiring
      guard_step51g_aggregate_surface_wiring
      guard_step51g_address_origin_legacy_wrapper_surface
      guard_step51g_expression_provenance_legacy_wrapper_surface
      guard_step51_provenance_origin_spine
      guard_step52_report_only_lanes_not_in_test
      guard_step52_no_post_closure_report_churn
      guard_step52_resource_decl_assignment_tracking
      guard_step52_resource_move_assignment_tracking
      guard_step52_resource_destructor_call_tracking
      guard_step52_resource_double_close_enforcement
      guard_step52_resource_close_after_move_enforcement
      guard_step52_resource_destructor_scheduled_enforcement
      guard_step52_resource_missing_cleanup_diagnostic
      guard_step52_resource_missing_cleanup_first_report
      guard_step52_resource_cleanup_boundary_validation
      guard_step52_resource_cleanup_boundary_terminal_states
      guard_step52_resource_cleanup_boundary_mixed_states
      guard_step52_resource_scope_exit_cleanup_boundary
      guard_step52_resource_function_exit_cleanup_integration
      guard_step52_resource_return_cleanup_integration
      guard_step52_resource_missing_cleanup_dedup
      guard_step52_resource_return_cleanup_dedup_integration
      guard_step52_resource_return_cleanup_terminal_states
      guard_step52_resource_return_cleanup_moved_terminal_states
      guard_step52_resource_function_exit_terminal_states
      guard_step52_resource_function_exit_moved_terminal_states
      guard_step52_resource_return_cleanup_mixed_terminal_states
      guard_step52_resource_function_exit_mixed_terminal_states
      guard_step52_resource_return_cleanup_scheduled_terminal_states
      guard_step52_resource_scope_exit_scheduled_terminal_states
      guard_step52_resource_return_cleanup_mixed_scheduled_terminal_states
      guard_step52_resource_scope_exit_mixed_scheduled_terminal_states
      guard_step52_resource_use_after_move_enforcement
      guard_parser_high_level_raw_casts
      guard_step44_no_high_level_raw_collection_casts
    )
    for guard_name in "${guards[@]}"; do
      just "$guard_name"
    done

# Bounded parallel guard suite: build gust first, then run only the bucket layer in parallel.
# `make-test-guards` above remains the default safe path and serial debugging fallback.
# Avoid nested high-fanout [parallel] dependencies here: concurrent ./gust + cc jobs can overload dev machines.
make-test-guards-parallel: gust _make-test-guards-parallel-inner

[parallel]
_make-test-guards-parallel-inner: make-test-guards-step44-text make-test-guards-policy

# Buckets below intentionally run their dependencies serially; only the bucket layer is parallel.
# Keep the policy bucket aligned with make-test-guards so Step 5.1G runs in both default guard modes.

make-test-guards-policy: guard_step51_report_only_lanes_not_in_test guard_step51g_default_guard_wiring guard_step51g_aggregate_surface_wiring guard_step51g_address_origin_legacy_wrapper_surface guard_step51g_expression_provenance_legacy_wrapper_surface guard_step51_provenance_origin_spine guard_step52_report_only_lanes_not_in_test guard_step52_no_post_closure_report_churn guard_step52_resource_decl_assignment_tracking guard_step52_resource_move_assignment_tracking guard_step52_resource_destructor_call_tracking guard_step52_resource_double_close_enforcement guard_step52_resource_close_after_move_enforcement guard_step52_resource_destructor_scheduled_enforcement guard_step52_resource_missing_cleanup_diagnostic guard_step52_resource_missing_cleanup_first_report guard_step52_resource_cleanup_boundary_validation guard_step52_resource_cleanup_boundary_terminal_states guard_step52_resource_cleanup_boundary_mixed_states guard_step52_resource_scope_exit_cleanup_boundary guard_step52_resource_function_exit_cleanup_integration guard_step52_resource_return_cleanup_integration guard_step52_resource_missing_cleanup_dedup guard_step52_resource_return_cleanup_dedup_integration guard_step52_resource_return_cleanup_terminal_states guard_step52_resource_return_cleanup_moved_terminal_states guard_step52_resource_function_exit_terminal_states guard_step52_resource_function_exit_moved_terminal_states guard_step52_resource_return_cleanup_mixed_terminal_states guard_step52_resource_function_exit_mixed_terminal_states guard_step52_resource_return_cleanup_scheduled_terminal_states guard_step52_resource_scope_exit_scheduled_terminal_states guard_step52_resource_return_cleanup_mixed_scheduled_terminal_states guard_step52_resource_scope_exit_mixed_scheduled_terminal_states guard_step52_resource_use_after_move_enforcement

make-test-guards-step44-text: guard_parser_high_level_raw_casts guard_step44_no_high_level_raw_collection_casts

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

make-test-suite-parallel:
    just make-test-guards-parallel
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

check-fast guard_name="":
    #!/usr/bin/env bash
    set -euo pipefail
    make
    if [ -n "{{guard_name}}" ]; then
      just "{{guard_name}}"
    else
      echo "ℹ️  check-fast: no focused guard supplied; ran build and whitespace checks only."
    fi
    git diff --check

check-step52:
    #!/usr/bin/env bash
    set -euo pipefail
    just make-test-guards
    make test
    git diff --check
