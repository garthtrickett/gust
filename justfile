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

guard_step52_transfer_state_surface_inventory:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 transfer-state surface inventory..."
    rg -n -F 'env_track_resource_move_assignment_if_applicable' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_track_resource_assignment_if_applicable' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_report_linear_resource_reassignment_requires_terminal' compiler/typechecker.gst >/dev/null
    rg -n -F 'requires cleanup before reassignment' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_try_move_open_linear_resource' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_try_schedule_open_linear_resource_destructor' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_try_borrow_open_linear_resource' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_open_linear_resource_state_name' compiler/typechecker.gst >/dev/null
    rg -n -F 'linear_resource_transfer_transition_is_allowed' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_open_linear_resource_transfer_transition_is_allowed' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_mark_open_linear_resource_moved' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_mark_open_linear_resource_closed' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_mark_open_linear_resource_destructor_scheduled' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_open_linear_resource_has_terminal_state' compiler/typechecker.gst >/dev/null
    rg -n -F 'LinearResourceUseAfterMove' compiler/typechecker.gst justfile-reports >/dev/null
    rg -n -F 'LinearResourceDoubleClose' compiler/typechecker.gst justfile-reports >/dev/null
    rg -n -F 'LinearResourceCloseAfterMove' compiler/typechecker.gst justfile-reports >/dev/null
    rg -n -F 'LinearResourceDestructorAlreadyScheduled' compiler/typechecker.gst justfile-reports >/dev/null
    rg -n -F 'LinearResourceInvalidTransfer' compiler/typechecker.gst justfile-reports >/dev/null
    rg -n -F 'compiler/typechecker_resource_use_after_move_pass_test_entry.gst' tests/test_runner.gst justfile >/dev/null
    rg -n -F 'compiler/typechecker_resource_use_after_move_rejected_test_entry.gst' tests/test_runner.gst justfile >/dev/null
    rg -n -F 'compiler/typechecker_resource_double_close_rejected_test_entry.gst' tests/test_runner.gst justfile-step52 >/dev/null
    rg -n -F 'compiler/typechecker_resource_close_after_move_rejected_test_entry.gst' tests/test_runner.gst justfile-step52 >/dev/null
    rg -n -F 'compiler/typechecker_resource_destructor_scheduled_rejected_test_entry.gst' tests/test_runner.gst justfile-step52 >/dev/null
    rg -n -F 'compiler/typechecker_resource_move_assignment_transfer_test_entry.gst' tests/test_runner.gst justfile-step52 >/dev/null
    rg -n -F 'compiler/typechecker_resource_reassignment_terminal_required_test_entry.gst' tests/test_runner.gst justfile-step52 >/dev/null
    rg -n -F 'compiler/typechecker_resource_transfer_transition_table_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/typechecker_resource_transfer_real_path_move_test_entry.gst' justfile >/dev/null
    rg -n -F 'guard_step52_transfer_state_matrix' justfile justfile-reports >/dev/null
    echo "✅ Step 5.2 transfer-state surface inventory guard passed."

guard_step52_transfer_state_transition_table:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 helper-level transfer transition table..."
    rg -n -F 'env_open_linear_resource_state_name' compiler/typechecker.gst >/dev/null
    rg -n -F 'linear_resource_transfer_transition_is_allowed' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_open_linear_resource_transfer_transition_is_allowed' compiler/typechecker.gst >/dev/null
    rg -n -F 'compiler/typechecker_resource_transfer_transition_table_test_entry.gst' justfile >/dev/null
    just guard-positive compiler/typechecker_resource_transfer_transition_table_test_entry.gst step52_transfer_state_transition_table
    echo "✅ Step 5.2 helper-level transfer transition table guard passed."

guard_step52_transfer_state_real_path_move:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 real move-assignment transfer-state validation..."
    rg -n -F 'LinearResourceInvalidTransfer' compiler/typechecker.gst justfile-reports >/dev/null
    rg -n -F 'env_report_linear_resource_invalid_transfer' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_report_linear_resource_move_transition_rejected' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_track_resource_move_assignment_if_applicable(env, assignment_lhs_resource_name_step52g, assignment_rhs_resource_name_step52h, get_expression_span(val_idx, ctx), ctx);' compiler/typechecker.gst >/dev/null
    rg -n -F 'compiler/typechecker_resource_transfer_real_path_move_test_entry.gst' justfile >/dev/null
    just guard-positive compiler/typechecker_resource_transfer_real_path_move_test_entry.gst step52_transfer_state_real_path_move
    echo "✅ Step 5.2 real move-assignment transfer-state validation guard passed."

guard_step52_transfer_state_matrix:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 transfer-state matrix guard..."
    rg -n -F 'guard_step52_transfer_state_transition_table' justfile justfile-reports >/dev/null
    rg -n -F 'guard_step52_transfer_state_real_path_move' justfile justfile-reports >/dev/null
    rg -n -F 'owned Resource should allow move transition' compiler/typechecker_resource_transfer_transition_table_test_entry.gst >/dev/null
    rg -n -F 'moved Resource should reject move transition' compiler/typechecker_resource_transfer_transition_table_test_entry.gst >/dev/null
    rg -n -F 'closed Resource should reject move transition' compiler/typechecker_resource_transfer_transition_table_test_entry.gst >/dev/null
    rg -n -F 'destructor-scheduled Resource should reject move transition' compiler/typechecker_resource_transfer_transition_table_test_entry.gst >/dev/null
    rg -n -F 'borrowed Resource should reject move transition' compiler/typechecker_resource_transfer_transition_table_test_entry.gst >/dev/null
    rg -n -F 'untracked Resource should reject move transition' compiler/typechecker_resource_transfer_transition_table_test_entry.gst >/dev/null
    rg -n -F 'move-after-scheduled Resource source' compiler/typechecker_resource_transfer_real_path_move_test_entry.gst >/dev/null
    just guard_step52_transfer_state_transition_table
    just guard_step52_transfer_state_real_path_move
    echo "✅ Step 5.2 transfer-state matrix guard passed."

guard_step52_defer_canonical_syntax_surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 canonical Resource defer syntax surface..."
    rg -n -F 'Defer {' compiler/ast.gst >/dev/null
    rg -n -F 'stmt.Defer.expr' compiler/ast.gst compiler/typechecker.gst >/dev/null
    rg -n -F 'defer close_resource(resource);' compiler/parser_resource_defer_canonical_surface_test_entry.gst >/dev/null
    rg -n -F 'canonical Resource cleanup form must parse as a Defer statement' compiler/parser_resource_defer_canonical_surface_test_entry.gst >/dev/null
    rg -n -F 'canonical Resource cleanup defer must wrap a call expression' compiler/parser_resource_defer_canonical_surface_test_entry.gst >/dev/null
    rg -n -F 'canonical Resource cleanup defer must have exactly one argument' compiler/parser_resource_defer_canonical_surface_test_entry.gst >/dev/null
    rg -n -F 'canonical Resource cleanup defer first argument must be a tracked Resource identifier surface' compiler/parser_resource_defer_canonical_surface_test_entry.gst >/dev/null
    just guard-positive compiler/parser_resource_defer_canonical_surface_test_entry.gst step52_defer_canonical_syntax_surface
    echo "✅ Step 5.2 canonical Resource defer syntax surface guard passed."

guard_step52_defer_destructor_candidate_recognizer:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 semantic defer destructor candidate recognizer..."
    rg -n -F 'env_defer_statement_resource_destructor_candidate_name' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_defer_statement_is_resource_destructor_candidate' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_open_linear_resource_destructor_name' compiler/typechecker.gst >/dev/null
    rg -n -F 'canonical defer destructor candidate should be recognized' compiler/typechecker_resource_defer_destructor_candidate_test_entry.gst >/dev/null
    rg -n -F 'defer destructor candidate recognition must not schedule the Resource yet' compiler/typechecker_resource_defer_destructor_candidate_test_entry.gst >/dev/null
    rg -n -F 'wrong destructor must not be a Resource destructor candidate' compiler/typechecker_resource_defer_destructor_candidate_test_entry.gst >/dev/null
    rg -n -F 'untracked first argument must not be a Resource destructor candidate' compiler/typechecker_resource_defer_destructor_candidate_test_entry.gst >/dev/null
    just guard-positive compiler/typechecker_resource_defer_destructor_candidate_test_entry.gst step52_defer_destructor_candidate_recognizer
    echo "✅ Step 5.2 semantic defer destructor candidate recognizer guard passed."

guard_step52_defer_real_path_scheduling:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 real Resource defer scheduling path..."
    rg -n -F 'env_try_schedule_open_linear_resource_destructor(env, defer_resource_name_step52ai, ctx);' compiler/typechecker.gst >/dev/null
    rg -n -F 'real canonical Resource defer should mark the Resource destructor_scheduled' compiler/typechecker_resource_defer_real_path_scheduling_test_entry.gst >/dev/null
    rg -n -F 'real Resource defer scheduling must not mark the Resource closed' compiler/typechecker_resource_defer_real_path_scheduling_test_entry.gst >/dev/null
    just guard-positive compiler/typechecker_resource_defer_real_path_scheduling_test_entry.gst step52_defer_real_path_scheduling
    echo "✅ Step 5.2 real Resource defer scheduling path guard passed."

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
      guard_step52_resource_declaration_auto_registration
      guard_step52_resource_assignment_auto_registration
      guard_step52_resource_move_assignment_transfer
      guard_step52_resource_reassignment_terminal_required
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
      guard_step52_transfer_state_surface_inventory
      guard_step52_transfer_state_transition_table
      guard_step52_transfer_state_real_path_move
      guard_step52_transfer_state_matrix
      guard_step52_defer_canonical_syntax_surface
      guard_step52_defer_destructor_candidate_recognizer
      guard_step52_defer_real_path_scheduling
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

make-test-guards-policy: guard_step51_report_only_lanes_not_in_test guard_step51g_default_guard_wiring guard_step51g_aggregate_surface_wiring guard_step51g_address_origin_legacy_wrapper_surface guard_step51g_expression_provenance_legacy_wrapper_surface guard_step51_provenance_origin_spine guard_step52_report_only_lanes_not_in_test guard_step52_no_post_closure_report_churn guard_step52_resource_declaration_auto_registration guard_step52_resource_assignment_auto_registration guard_step52_resource_move_assignment_transfer guard_step52_resource_reassignment_terminal_required guard_step52_resource_decl_assignment_tracking guard_step52_resource_move_assignment_tracking guard_step52_resource_double_close_enforcement guard_step52_resource_close_after_move_enforcement guard_step52_resource_destructor_scheduled_enforcement guard_step52_resource_missing_cleanup_diagnostic guard_step52_resource_missing_cleanup_first_report guard_step52_resource_cleanup_boundary_validation guard_step52_resource_cleanup_boundary_terminal_states guard_step52_resource_cleanup_boundary_mixed_states guard_step52_resource_scope_exit_cleanup_boundary guard_step52_resource_function_exit_cleanup_integration guard_step52_resource_return_cleanup_integration guard_step52_resource_missing_cleanup_dedup guard_step52_resource_return_cleanup_dedup_integration guard_step52_resource_return_cleanup_terminal_states guard_step52_resource_return_cleanup_moved_terminal_states guard_step52_resource_function_exit_terminal_states guard_step52_resource_function_exit_moved_terminal_states guard_step52_resource_return_cleanup_mixed_terminal_states guard_step52_resource_function_exit_mixed_terminal_states guard_step52_resource_return_cleanup_scheduled_terminal_states guard_step52_resource_scope_exit_scheduled_terminal_states guard_step52_resource_return_cleanup_mixed_scheduled_terminal_states guard_step52_resource_scope_exit_mixed_scheduled_terminal_states guard_step52_resource_use_after_move_enforcement

make-test-guards-step52-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 surface-only guard batch."
    needles=(
      guard_step52_report_only_lanes_not_in_test
      guard_step52_no_post_closure_report_churn
      guard_step52_resource_declaration_auto_registration
      guard_step52_resource_assignment_auto_registration
      guard_step52_resource_move_assignment_transfer
      guard_step52_resource_reassignment_terminal_required
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
      guard_step52_transfer_state_surface_inventory
      guard_step52_transfer_state_transition_table
      guard_step52_transfer_state_real_path_move
      guard_step52_transfer_state_matrix
      guard_step52_defer_canonical_syntax_surface
      guard_step52_defer_destructor_candidate_recognizer
      guard_step52_defer_real_path_scheduling
    )
    for needle in "${needles[@]}"; do
      rg -n -F "$needle" justfile justfile-step52 justfile-reports Makefile tests/test_runner.gst compiler/*.gst >/dev/null
    done
    rg -n -F 'compiler/typechecker_resource_return_cleanup_mixed_scheduled_terminal_states_test_entry.gst' tests/test_runner.gst justfile-step52 >/dev/null
    rg -n -F 'compiler/typechecker_resource_scope_exit_mixed_scheduled_terminal_states_test_entry.gst' tests/test_runner.gst justfile-step52 >/dev/null
    rg -n -F 'return cleanup mixed scheduled terminal-state integration' justfile-reports >/dev/null
    rg -n -F 'scope-exit mixed scheduled terminal-state integration' justfile-reports >/dev/null
    echo "✅ Step 5.2 surface-only guard batch passed."

run-step52-positive-batch:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Running batched Step 5.2 positive fixture runner."
    rg -n -F 'compiler/typechecker_resource_declaration_bridge_test_entry.gst' tests/test_runner.gst >/dev/null
    rg -n -F 'compiler/typechecker_resource_declaration_auto_registration_test_entry.gst' tests/test_runner.gst >/dev/null
    rg -n -F 'compiler/typechecker_resource_assignment_auto_registration_test_entry.gst' tests/test_runner.gst >/dev/null
    rg -n -F 'compiler/typechecker_resource_move_assignment_transfer_test_entry.gst' tests/test_runner.gst >/dev/null
    rg -n -F 'compiler/typechecker_resource_reassignment_terminal_required_test_entry.gst' tests/test_runner.gst >/dev/null
    rg -n -F 'compiler/typechecker_resource_assignment_bridge_test_entry.gst' tests/test_runner.gst >/dev/null
    rg -n -F 'compiler/typechecker_resource_return_cleanup_mixed_scheduled_terminal_states_test_entry.gst' tests/test_runner.gst >/dev/null
    rg -n -F 'compiler/typechecker_resource_scope_exit_mixed_scheduled_terminal_states_test_entry.gst' tests/test_runner.gst >/dev/null
    mkdir -p build
    echo "⚙️  Compiling native batched Step 5.2 positive runner from tests/test_runner.gst..."
    ./gust tests/test_runner.gst | grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > build/test_runner_step52_positive.c
    rg -n -F 'compiler/typechecker_resource_declaration_auto_registration_test_entry.gst' build/test_runner_step52_positive.c >/dev/null
    rg -n -F 'compiler/typechecker_resource_assignment_auto_registration_test_entry.gst' build/test_runner_step52_positive.c >/dev/null
    rg -n -F 'compiler/typechecker_resource_move_assignment_transfer_test_entry.gst' build/test_runner_step52_positive.c >/dev/null
    rg -n -F 'compiler/typechecker_resource_reassignment_terminal_required_test_entry.gst' build/test_runner_step52_positive.c >/dev/null
    rg -n -F 'compiler/typechecker_resource_return_cleanup_mixed_scheduled_terminal_states_test_entry.gst' build/test_runner_step52_positive.c >/dev/null
    rg -n -F 'compiler/typechecker_resource_scope_exit_mixed_scheduled_terminal_states_test_entry.gst' build/test_runner_step52_positive.c >/dev/null
    cat src/runtime.c build/test_runner_step52_positive.c > build/test_runner_step52_positive_final.c
    CC_BIN="${CC:-cc}"; CFLAGS_VAL="${CFLAGS:--O2 -Wall -pthread}"; INCLUDES_VAL="${INCLUDES:--Isrc}"; "$CC_BIN" $CFLAGS_VAL $INCLUDES_VAL build/test_runner_step52_positive_final.c -o build/test_runner_step52_positive_bin
    echo "🏃 Running native batched Step 5.2 positive runner..."
    ./build/test_runner_step52_positive_bin
    echo "✅ Batched Step 5.2 positive fixture runner passed."

run-step52-negative-batch:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Checking batched Step 5.2 negative diagnostic harness."
    diagnostics=(
      LinearResourceUseAfterMove
      LinearResourceDoubleClose
      LinearResourceCloseAfterMove
      LinearResourceDestructorAlreadyScheduled
      LinearResourceInvalidTransfer
      LinearResourceMissingCleanup
    )
    for diagnostic in "${diagnostics[@]}"; do
      rg -n -F "$diagnostic" compiler/typechecker.gst >/dev/null
      rg -n -F "$diagnostic" justfile-reports >/dev/null
    done
    fixtures=(
      compiler/typechecker_resource_use_after_move_rejected_test_entry.gst
      compiler/typechecker_resource_double_close_rejected_test_entry.gst
      compiler/typechecker_resource_close_after_move_rejected_test_entry.gst
      compiler/typechecker_resource_destructor_scheduled_rejected_test_entry.gst
      compiler/typechecker_resource_missing_cleanup_diagnostic_test_entry.gst
      compiler/typechecker_resource_missing_cleanup_first_report_test_entry.gst
      compiler/typechecker_resource_function_exit_cleanup_integration_test_entry.gst
      compiler/typechecker_resource_return_cleanup_integration_test_entry.gst
      compiler/typechecker_resource_missing_cleanup_dedup_test_entry.gst
      compiler/typechecker_resource_return_cleanup_dedup_integration_test_entry.gst
    )
    for fixture in "${fixtures[@]}"; do
      rg -n -F "$fixture" tests/test_runner.gst justfile-step52 >/dev/null
    done
    labels=(
      step52_resource_use_after_move_rejected
      step52_resource_double_close_rejected
      step52_resource_close_after_move_rejected
      step52_resource_destructor_scheduled_rejected
      step52_resource_missing_cleanup_diagnostic
      step52_resource_missing_cleanup_first_report
      step52_resource_function_exit_cleanup_integration
      step52_resource_return_cleanup_integration
      step52_resource_missing_cleanup_dedup
      step52_resource_return_cleanup_dedup_integration
    )
    for label in "${labels[@]}"; do
      rg -n -F "$label" tests/test_runner.gst justfile justfile-step52 >/dev/null
    done
    echo "✅ Batched Step 5.2 negative diagnostic harness passed."

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
      echo "ℹ️  check-fast: ignoring focused guard '{{guard_name}}' to keep this lane build-only. Use 'just check-focused {{guard_name}}' when you want that full guard."
    else
      echo "ℹ️  check-fast: ran build and whitespace checks only."
    fi
    git diff --check

check-focused guard_name:
    #!/usr/bin/env bash
    set -euo pipefail
    make
    just "{{guard_name}}"
    git diff --check

check-step52:
    #!/usr/bin/env bash
    set -euo pipefail
    make gust
    just make-test-guards-step52-surface
    just guard_step52_transfer_state_surface_inventory
    just guard_step52_transfer_state_transition_table
    just guard_step52_transfer_state_real_path_move
    just guard_step52_transfer_state_matrix
    just guard_step52_defer_canonical_syntax_surface
    just guard_step52_defer_destructor_candidate_recognizer
    just guard_step52_defer_real_path_scheduling
    just run-step52-positive-batch
    just run-step52-negative-batch
    make test
    git diff --check
