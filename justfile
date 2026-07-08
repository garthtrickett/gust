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

guard-pr-fast-shard shard:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔀 Running PR fast shard: {{shard}}"
    rm -rf build/guards
    rm -f to.log
    case "{{shard}}" in
      cranelift-return-int)
        just guard-cranelift-experiment-manifest-surface
        just guard-cranelift-backend-surface
        just guard-cranelift-return-int-native-smoke
        ;;
      cranelift-local-binding)
        just guard-cranelift-experiment-manifest-surface
        just guard-cranelift-backend-surface
        just guard-cranelift-local-binding-read-native-smoke
        ;;
      cranelift-branch)
        just guard-cranelift-experiment-manifest-surface
        just guard-cranelift-backend-surface
        just guard-cranelift-conditional-branch-native-smoke
        ;;
      cranelift-differential)
        just guard-cranelift-experiment-manifest-surface
        just guard-cranelift-backend-surface
        just guard-cranelift-mir-to-c-differential-native-smoke
        ;;
      cranelift-backend-suite)
        just guard-cranelift-experimental-backend-suite
        ;;
      mir-to-c-return-int)
        just guard-mir-to-c-return-int-literal-native-smoke
        ;;
      routed-return-int)
        just guard-mir-feature-return-int-routed-execution
        ;;
      migration-return-int)
        just guard-mir-owned-return-int-literal-validation
        just guard-mir-feature-return-int-routed-execution
        ;;
      migration-local-binding)
        just guard-mir-owned-local-binding-read-validation
        just guard-mir-feature-local-binding-read-routed-execution
        ;;
      migration-if-else)
        just guard-mir-owned-if-else-return-int-validation
        just guard-mir-feature-if-else-return-int-routed-execution
        ;;
      migration-provenance)
        just guard-mir-owned-local-binding-read-provenance-metadata-validation
        just guard-mir-feature-local-binding-read-provenance-metadata-routed-execution
        ;;
      *)
        echo "unknown PR fast shard: {{shard}}"
        echo "expected one of: cranelift-return-int, cranelift-local-binding, cranelift-branch, cranelift-differential, cranelift-backend-suite, mir-to-c-return-int, routed-return-int, migration-return-int, migration-local-binding, migration-if-else, migration-provenance"
        exit 1
        ;;
    esac

guard-pr-fast-ci-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking PR fast CI surface..."
    workflow=".github/workflows/pr-fast.yml"
    if [ ! -f "$workflow" ]; then
      echo "Missing $workflow. Cloud setup Step 2 must add the PR fast workflow before Step 3 can guard it."
      exit 1
    fi

    rg -n -F 'name: PR Fast' "$workflow" >/dev/null
    rg -n -F 'pull_request:' "$workflow" >/dev/null
    rg -n -F 'push:' "$workflow" >/dev/null
    rg -n -F 'workflow_dispatch:' "$workflow" >/dev/null
    rg -n -F 'permissions:' "$workflow" >/dev/null
    rg -n -F 'contents: read' "$workflow" >/dev/null

    rg -n -F 'jobs:' "$workflow" >/dev/null
    rg -n -F 'build:' "$workflow" >/dev/null
    rg -n -F 'guard:' "$workflow" >/dev/null
    rg -n -F 'final:' "$workflow" >/dev/null
    rg -n -F 'needs: build' "$workflow" >/dev/null
    rg -n -F 'needs: guard' "$workflow" >/dev/null
    rg -n -F 'PR fast CI surface guard' "$workflow" >/dev/null
    rg -n -F 'just guard-pr-fast-ci-surface' "$workflow" >/dev/null

    rg -n -F 'strategy:' "$workflow" >/dev/null
    rg -n -F 'fail-fast: false' "$workflow" >/dev/null
    rg -n -F 'matrix:' "$workflow" >/dev/null
    rg -n -F 'shard:' "$workflow" >/dev/null

    rg -n -F 'cranelift-return-int' "$workflow" justfile >/dev/null
    rg -n -F 'cranelift-local-binding' "$workflow" justfile >/dev/null
    rg -n -F 'cranelift-branch' "$workflow" justfile >/dev/null
    rg -n -F 'cranelift-differential' "$workflow" justfile >/dev/null
    rg -n -F 'cranelift-backend-suite' "$workflow" justfile >/dev/null
    rg -n -F 'mir-to-c-return-int' "$workflow" justfile >/dev/null
    rg -n -F 'routed-return-int' "$workflow" justfile >/dev/null
    rg -n -F 'migration-return-int' "$workflow" justfile >/dev/null
    rg -n -F 'migration-local-binding' "$workflow" justfile >/dev/null
    rg -n -F 'migration-if-else' "$workflow" justfile >/dev/null
    rg -n -F 'migration-provenance' "$workflow" justfile >/dev/null

    rg -n -F 'guard-pr-fast-shard shard:' justfile >/dev/null
    pr_fast_dispatcher_body="$(sed -n '/^guard-pr-fast-shard shard:/,/^guard-pr-fast-ci-surface:/p' justfile)"
    printf '%s\n' "$pr_fast_dispatcher_body" | rg -n -F 'cranelift-differential)' >/dev/null
    printf '%s\n' "$pr_fast_dispatcher_body" | rg -n -F 'just guard-cranelift-mir-to-c-differential-native-smoke' >/dev/null
    printf '%s\n' "$pr_fast_dispatcher_body" | rg -n -F 'cranelift-backend-suite)' >/dev/null
    printf '%s\n' "$pr_fast_dispatcher_body" | rg -n -F 'just guard-cranelift-experimental-backend-suite' >/dev/null
    rg -n -F 'just guard-pr-fast-shard' "$workflow" >/dev/null
    rg -n -F 'matrix.shard' "$workflow" >/dev/null

    rg -n -F 'actions/checkout@v4' "$workflow" >/dev/null
    rg -n -F 'actions/upload-artifact@v4' "$workflow" >/dev/null
    rg -n -F 'actions/download-artifact@v4' "$workflow" >/dev/null
    rg -n -F 'name: gust-build' "$workflow" >/dev/null
    rg -n -F 'if-no-files-found: error' "$workflow" >/dev/null
    rg -n -F './gust' "$workflow" >/dev/null
    rg -n -F 'build/' "$workflow" >/dev/null
    rg -n -F 'chmod +x ./gust' "$workflow" >/dev/null

    rg -n -F 'sudo apt-get install -y build-essential curl ripgrep' "$workflow" >/dev/null
    rg -n -F 'https://just.systems/install.sh' "$workflow" >/dev/null
    rg -n -F 'bash -s -- --tag 1.55.1 --to "$HOME/.local/bin"' "$workflow" >/dev/null
    rg -n -F 'GITHUB_PATH' "$workflow" >/dev/null
    rg -n -F '"$HOME/.local/bin/just" --version' "$workflow" >/dev/null

    if rg -n -F 'actions/cache' "$workflow" >/dev/null; then
      echo "Cloud setup Step 3 forbids CI cache wiring. Add cache only in a later explicit step."
      exit 1
    fi
    if rg -n -F 'migration-suite' "$workflow" >/dev/null; then
      echo "PR fast CI must split the slow migration-suite aggregate into focused migration-* shards."
      exit 1
    fi
    if rg -n -F 'apt-get install -y build-essential just ripgrep' "$workflow" >/dev/null; then
      echo "PR fast CI must not install just from apt; apt just is too old for this justfile."
      exit 1
    fi
    if rg -n -F 'cargo install just --locked' "$workflow" >/dev/null; then
      echo "PR fast CI must not compile just from source; use the prebuilt just.systems installer."
      exit 1
    fi
    if rg -n -F 'https://sh.rustup.rs' "$workflow" >/dev/null; then
      echo "PR fast CI must not install Rust just to compile just; use the prebuilt just.systems installer."
      exit 1
    fi

    shard_count="$(awk '/shard:/{flag=1; next} flag && /^[[:space:]]*steps:/{flag=0} flag && /^[[:space:]]*- /{count++} END{print count+0}' "$workflow")"
    if [ "$shard_count" != "11" ]; then
      echo "Expected exactly 11 PR fast matrix shards, found $shard_count."
      awk '/shard:/{flag=1; next} flag && /^[[:space:]]*steps:/{flag=0} flag{print}' "$workflow"
      exit 1
    fi

    echo "✅ PR fast CI surface guard passed."

guard-cloud-heavy-shard shard:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔀 Running cloud heavy shard: {{shard}}"
    export CC="${CC:-cc}"
    export CFLAGS="${CFLAGS:--O0 -w -pthread}"
    rm -rf build/guards
    rm -f to.log
    case "{{shard}}" in
      phase9-branch)
        just guard-cranelift-experimental-backend-suite
        ;;
      mir-branch)
        just guard-mir-to-c-conditional-branch-native-smoke
        just guard-mir-feature-if-else-return-int-routed-execution
        ;;
      migration-surfaces)
        just guard-mir-feature-harness-surface
        just guard-mir-feature-registry-surface
        just guard-mir-ast-to-c-retirement-manifest-surface
        ;;
      migration-return-int)
        just guard-mir-owned-return-int-literal-validation
        just guard-mir-feature-return-int-routed-execution
        ;;
      migration-local-binding)
        just guard-mir-owned-local-binding-read-validation
        just guard-mir-feature-local-binding-read-routed-execution
        ;;
      migration-if-else)
        just guard-mir-owned-if-else-return-int-validation
        just guard-mir-feature-if-else-return-int-routed-execution
        ;;
      migration-provenance)
        just guard-mir-owned-local-binding-read-provenance-metadata-validation
        just guard-mir-feature-local-binding-read-provenance-metadata-routed-execution
        ;;
      step51-policy)
        just guard_step51_report_only_lanes_not_in_test
        just guard_step51g_default_guard_wiring
        just guard_step51g_aggregate_surface_wiring
        just guard_step51g_address_origin_legacy_wrapper_surface
        just guard_step51g_expression_provenance_legacy_wrapper_surface
        just guard_step51_provenance_origin_spine
        ;;
      step52-registration)
        just guard_step52_report_only_lanes_not_in_test
        just guard_step52_no_post_closure_report_churn
        just guard_step52_resource_declaration_auto_registration
        just guard_step52_resource_assignment_auto_registration
        just guard_step52_resource_move_assignment_transfer
        just guard_step52_resource_reassignment_terminal_required
        just guard_step52_resource_decl_assignment_tracking
        just guard_step52_resource_move_assignment_tracking
        ;;
      step52-lifetime-diagnostics)
        just guard_step52_resource_destructor_call_tracking
        just guard_step52_resource_double_close_enforcement
        just guard_step52_resource_close_after_move_enforcement
        just guard_step52_resource_destructor_scheduled_enforcement
        just guard_step52_resource_missing_cleanup_diagnostic
        just guard_step52_resource_missing_cleanup_first_report
        just guard_step52_resource_use_after_move_enforcement
        ;;
      step52-cleanup-boundary)
        just guard_step52_resource_cleanup_boundary_validation
        just guard_step52_resource_cleanup_boundary_terminal_states
        just guard_step52_resource_cleanup_boundary_mixed_states
        just guard_step52_resource_scope_exit_cleanup_boundary
        just guard_step52_resource_function_exit_cleanup_integration
        just guard_step52_resource_return_cleanup_integration
        just guard_step52_resource_missing_cleanup_dedup
        just guard_step52_resource_return_cleanup_dedup_integration
        ;;
      step52-terminal-states)
        just guard_step52_resource_return_cleanup_terminal_states
        just guard_step52_resource_return_cleanup_moved_terminal_states
        just guard_step52_resource_function_exit_terminal_states
        just guard_step52_resource_function_exit_moved_terminal_states
        just guard_step52_resource_return_cleanup_mixed_terminal_states
        just guard_step52_resource_function_exit_mixed_terminal_states
        just guard_step52_resource_return_cleanup_scheduled_terminal_states
        just guard_step52_resource_scope_exit_scheduled_terminal_states
        just guard_step52_resource_return_cleanup_mixed_scheduled_terminal_states
        just guard_step52_resource_scope_exit_mixed_scheduled_terminal_states
        ;;
      step52-transfer-defer)
        just guard_step52_transfer_state_surface_inventory
        just guard_step52_transfer_state_transition_table
        just guard_step52_transfer_state_real_path_move
        just guard_step52_transfer_state_matrix
        just guard_step52_defer_canonical_syntax_surface
        just guard_step52_defer_destructor_candidate_recognizer
        just guard_step52_defer_real_path_scheduling
        just guard_step52_defer_close_manual_interaction
        just guard_step52_defer_function_body_scheduled_terminal
        ;;
      step52-directory)
        just guard_step52_open_directories_legacy_freeze
        just guard_step52_directory_resource_parity_metadata
        just guard_step52_directory_resource_shadow_tracking
        just guard_step52_directory_resource_cleanup_boundary_routing
        just guard_step52_directory_resource_close_diagnostics_routing
        just guard_step52_directory_resource_source_of_truth_flip
        just guard_step52_directory_resource_no_open_directories_enforcement_reads
        ;;
      runner-surface)
        just guard-test-runner-bounded-concurrency-surface
        ;;
      parser-raw-casts)
        just guard_parser_high_level_raw_casts
        just guard_step44_no_high_level_raw_collection_casts
        ;;
      *)
        echo "unknown cloud heavy shard: {{shard}}"
        echo "expected one of: phase9-branch, mir-branch, migration-surfaces, migration-return-int, migration-local-binding, migration-if-else, migration-provenance, step51-policy, step52-registration, step52-lifetime-diagnostics, step52-cleanup-boundary, step52-terminal-states, step52-transfer-defer, step52-directory, runner-surface, parser-raw-casts"
        exit 1
        ;;
    esac

guard-cloud-heavy-ci-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking cloud heavy CI surface..."
    workflow=".github/workflows/heavy-guards.yml"
    if [ ! -f "$workflow" ]; then
      echo "Missing $workflow. Heavy guard cloud workflow must exist."
      exit 1
    fi

    rg -n -F 'name: Heavy Guards' "$workflow" >/dev/null
    rg -n -F 'pull_request:' "$workflow" >/dev/null
    rg -n -F 'push:' "$workflow" >/dev/null
    rg -n -F 'workflow_dispatch:' "$workflow" >/dev/null
    rg -n -F 'permissions:' "$workflow" >/dev/null
    rg -n -F 'contents: read' "$workflow" >/dev/null

    rg -n -F 'jobs:' "$workflow" >/dev/null
    rg -n -F 'build:' "$workflow" >/dev/null
    rg -n -F 'guard:' "$workflow" >/dev/null
    rg -n -F 'final:' "$workflow" >/dev/null
    rg -n -F 'needs: build' "$workflow" >/dev/null
    rg -n -F 'needs: guard' "$workflow" >/dev/null
    rg -n -F 'strategy:' "$workflow" >/dev/null
    rg -n -F 'fail-fast: false' "$workflow" >/dev/null
    rg -n -F 'matrix:' "$workflow" >/dev/null
    rg -n -F 'shard:' "$workflow" >/dev/null

    rg -n -F 'phase9-branch' "$workflow" justfile >/dev/null
    rg -n -F 'mir-branch' "$workflow" justfile >/dev/null
    rg -n -F 'migration-surfaces' "$workflow" justfile >/dev/null
    rg -n -F 'migration-return-int' "$workflow" justfile >/dev/null
    rg -n -F 'migration-local-binding' "$workflow" justfile >/dev/null
    rg -n -F 'migration-if-else' "$workflow" justfile >/dev/null
    rg -n -F 'migration-provenance' "$workflow" justfile >/dev/null
    rg -n -F 'step51-policy' "$workflow" justfile >/dev/null
    rg -n -F 'step52-registration' "$workflow" justfile >/dev/null
    rg -n -F 'step52-lifetime-diagnostics' "$workflow" justfile >/dev/null
    rg -n -F 'step52-cleanup-boundary' "$workflow" justfile >/dev/null
    rg -n -F 'step52-terminal-states' "$workflow" justfile >/dev/null
    rg -n -F 'step52-transfer-defer' "$workflow" justfile >/dev/null
    rg -n -F 'step52-directory' "$workflow" justfile >/dev/null
    rg -n -F 'runner-surface' "$workflow" justfile >/dev/null
    rg -n -F 'parser-raw-casts' "$workflow" justfile >/dev/null

    rg -n -F 'guard-cloud-heavy-shard shard:' justfile >/dev/null
    cloud_heavy_dispatcher_body="$(sed -n '/^guard-cloud-heavy-shard shard:/,/^guard-cloud-heavy-ci-surface:/p' justfile)"
    printf '%s\n' "$cloud_heavy_dispatcher_body" | rg -n -F 'phase9-branch)' >/dev/null
    printf '%s\n' "$cloud_heavy_dispatcher_body" | rg -n -F 'just guard-cranelift-experimental-backend-suite' >/dev/null
    rg -n -F 'just guard-cloud-heavy-shard' "$workflow" >/dev/null
    rg -n -F 'matrix.shard' "$workflow" >/dev/null

    rg -n -F 'actions/checkout@v4' "$workflow" >/dev/null
    rg -n -F 'actions/upload-artifact@v4' "$workflow" >/dev/null
    rg -n -F 'actions/download-artifact@v4' "$workflow" >/dev/null
    rg -n -F 'name: gust-build' "$workflow" >/dev/null
    rg -n -F 'if-no-files-found: error' "$workflow" >/dev/null
    rg -n -F './gust' "$workflow" >/dev/null
    rg -n -F 'build/' "$workflow" >/dev/null
    rg -n -F 'chmod +x ./gust' "$workflow" >/dev/null

    rg -n -F 'sudo apt-get install -y build-essential curl ripgrep' "$workflow" >/dev/null
    rg -n -F 'https://just.systems/install.sh' "$workflow" >/dev/null
    rg -n -F 'bash -s -- --tag 1.55.1 --to "$HOME/.local/bin"' "$workflow" >/dev/null
    rg -n -F 'GITHUB_PATH' "$workflow" >/dev/null
    rg -n -F '"$HOME/.local/bin/just" --version' "$workflow" >/dev/null

    if rg -n -F 'actions/cache' "$workflow" >/dev/null; then
      echo "Cloud heavy guard workflow must not enable cache yet."
      exit 1
    fi
    if rg -n -F 'make-test-guards-fast-c' "$workflow" >/dev/null; then
      echo "Cloud heavy guard workflow must split make-test-guards-fast-c into focused matrix shards."
      exit 1
    fi
    if rg -n -F 'guard-mir-feature-migration-suite' "$workflow" >/dev/null; then
      echo "Cloud heavy guard workflow must split guard-mir-feature-migration-suite into focused matrix shards."
      exit 1
    fi
    if rg -n -F 'cargo install just --locked' "$workflow" >/dev/null; then
      echo "Cloud heavy guard workflow must not compile just from source; use the prebuilt just.systems installer."
      exit 1
    fi
    if rg -n -F 'https://sh.rustup.rs' "$workflow" >/dev/null; then
      echo "Cloud heavy guard workflow must not install Rust just to compile just."
      exit 1
    fi

    shard_count="$(awk '/shard:/{flag=1; next} flag && /^[[:space:]]*steps:/{flag=0} flag && /^[[:space:]]*- /{count++} END{print count+0}' "$workflow")"
    if [ "$shard_count" != "16" ]; then
      echo "Expected exactly 16 cloud heavy matrix shards, found $shard_count."
      awk '/shard:/{flag=1; next} flag && /^[[:space:]]*steps:/{flag=0} flag{print}' "$workflow"
      exit 1
    fi

    echo "✅ Cloud heavy CI surface guard passed."

guard-step51-hashmap-get-value:
    just guard compiler/typechecker_hashmap_get_value_provenance_test_entry.gst

guard-step51-hashmap-get-value-field:
    just guard compiler/typechecker_hashmap_get_value_field_provenance_test_entry.gst

guard-step51-non-launder-hashmap-get-value:
    just guard compiler/typechecker_non_laundering_hashmap_get_value_test_entry.gst

guard-step51-non-launder-hashmap-get-value-field:
    just guard compiler/typechecker_non_laundering_hashmap_get_value_field_test_entry.gst

guard-mir-data-structures-smoke:
    just guard compiler/mir_data_structures_smoke_test_entry.gst

guard-mir-debug-leaf-smoke:
    just guard compiler/mir_debug_leaf_smoke_test_entry.gst

guard-mir-debug-printer-smoke:
    just guard compiler/mir_debug_printer_smoke_test_entry.gst

guard-mir-debug-printer-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking MIR debug printer surface..."
    rg -n -F 'func mir_debug_stmt_kind' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_debug_value_kind' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_debug_terminator_kind' compiler/mir.gst >/dev/null
    rg -n -F 'type MirResourceKind enum' compiler/mir.gst >/dev/null
    rg -n -F 'type MirResourceState enum' compiler/mir.gst >/dev/null
    rg -n -F 'type MirProvenanceKind enum' compiler/mir.gst >/dev/null
    rg -n -F 'type MirNativeBoundaryKind enum' compiler/mir.gst >/dev/null
    rg -n -F 'type MirResourceMetadata[ctx] struct' compiler/mir.gst >/dev/null
    rg -n -F 'type MirProvenanceMetadata[ctx] struct' compiler/mir.gst >/dev/null
    rg -n -F 'type MirNativeBoundaryMetadata[ctx] struct' compiler/mir.gst >/dev/null
    rg -n -F 'resource_metadata' compiler/mir.gst compiler/mir_data_structures_smoke_test_entry.gst >/dev/null
    rg -n -F 'provenance_metadata' compiler/mir.gst compiler/mir_data_structures_smoke_test_entry.gst >/dev/null
    rg -n -F 'native_boundary_metadata' compiler/mir.gst compiler/mir_data_structures_smoke_test_entry.gst >/dev/null
    rg -n -F 'func mir_empty_resource_metadata_vector' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_empty_provenance_metadata_vector' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_empty_native_boundary_metadata_vector' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_make_resource_metadata' compiler/mir.gst compiler/mir_data_structures_smoke_test_entry.gst >/dev/null
    rg -n -F 'func mir_make_provenance_metadata' compiler/mir.gst compiler/mir_data_structures_smoke_test_entry.gst >/dev/null
    rg -n -F 'func mir_make_native_boundary_metadata' compiler/mir.gst compiler/mir_data_structures_smoke_test_entry.gst >/dev/null
    rg -n -F 'func mir_debug_resource_kind' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_debug_resource_state' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_debug_provenance_kind' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_debug_native_boundary_kind' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_debug_print_program' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_debug_print_function' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_debug_print_block' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_debug_print_stmt' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_debug_print_value' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_debug_print_terminator' compiler/mir.gst >/dev/null
    rg -n -F 'MirStmt.LocalSet' compiler/mir.gst compiler/mir_debug_leaf_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirValue.LocalRead' compiler/mir.gst compiler/mir_debug_leaf_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirTerminator.Return' compiler/mir.gst compiler/mir_debug_leaf_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirTerminator.Jump' compiler/mir.gst compiler/mir_debug_leaf_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirTerminator.Branch' compiler/mir.gst compiler/mir_debug_leaf_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirResourceKind.LinearResource' compiler/mir.gst compiler/mir_debug_leaf_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirResourceKind.DirectoryResource' compiler/mir.gst compiler/mir_debug_leaf_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirResourceState.DestructorScheduled' compiler/mir.gst compiler/mir_debug_leaf_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirProvenanceKind.NativeBoundary' compiler/mir.gst compiler/mir_debug_leaf_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirProvenanceKind.ResourceDestructor' compiler/mir.gst compiler/mir_debug_leaf_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirNativeBoundaryKind.RuntimeCall' compiler/mir.gst compiler/mir_debug_leaf_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirNativeBoundaryKind.ExternFunction' compiler/mir.gst compiler/mir_debug_leaf_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirNativeBoundaryKind.LayoutSensitiveCall' compiler/mir.gst compiler/mir_debug_leaf_smoke_test_entry.gst >/dev/null
    rg -n -F 'func mir_make_terminator_jump' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_make_terminator_branch' compiler/mir.gst >/dev/null
    rg -n -F 'target_block' compiler/mir.gst compiler/mir_data_structures_smoke_test_entry.gst >/dev/null
    rg -n -F 'then_block' compiler/mir.gst compiler/mir_data_structures_smoke_test_entry.gst >/dev/null
    rg -n -F 'else_block' compiler/mir.gst compiler/mir_data_structures_smoke_test_entry.gst >/dev/null
    rg -n -F 'mir.program' compiler/mir.gst compiler/mir_debug_printer_smoke_test_entry.gst >/dev/null
    rg -n -F 'mir.function' compiler/mir.gst compiler/mir_debug_printer_smoke_test_entry.gst >/dev/null
    rg -n -F 'mir.block' compiler/mir.gst compiler/mir_debug_printer_smoke_test_entry.gst >/dev/null
    rg -n -F 'compiler/mir_debug_leaf_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_debug_printer_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'guard-mir-debug-leaf-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-debug-printer-smoke' justfile >/dev/null
    echo "✅ MIR debug printer surface guard passed."

guard-mir-lower-tiny-function-fixture-smoke:
    just guard compiler/mir_lower_tiny_function_fixture_smoke_test_entry.gst

guard-mir-lower-function-shell-smoke:
    just guard compiler/mir_lower_function_shell_smoke_test_entry.gst

guard-mir-lower-return-int-literal-smoke:
    just guard compiler/mir_lower_return_int_literal_smoke_test_entry.gst

guard-mir-lower-local-binding-read-smoke:
    just guard compiler/mir_lower_local_binding_read_smoke_test_entry.gst

guard-mir-lower-resource-metadata-smoke:
    just guard compiler/mir_lower_resource_metadata_smoke_test_entry.gst

guard-mir-lower-provenance-metadata-smoke:
    just guard compiler/mir_lower_provenance_metadata_smoke_test_entry.gst

guard-mir-lower-native-boundary-metadata-smoke:
    just guard compiler/mir_lower_native_boundary_metadata_smoke_test_entry.gst

guard-mir-lower-block-jump-smoke:
    just guard compiler/mir_lower_block_jump_smoke_test_entry.gst

guard-mir-lower-conditional-branch-smoke:
    just guard compiler/mir_lower_conditional_branch_smoke_test_entry.gst

guard-mir-to-c-entry-smoke:
    just guard compiler/mir_to_c_entry_smoke_test_entry.gst

guard-mir-to-c-function-shell-smoke:
    just guard compiler/mir_to_c_function_shell_smoke_test_entry.gst

guard-mir-to-c-return-int-literal-smoke:
    just guard compiler/mir_to_c_return_int_literal_smoke_test_entry.gst

guard-mir-to-c-local-binding-read-smoke:
    just guard compiler/mir_to_c_local_binding_read_smoke_test_entry.gst

guard-mir-to-c-block-jump-smoke:
    just guard compiler/mir_to_c_block_jump_smoke_test_entry.gst

guard-mir-to-c-conditional-branch-smoke:
    just guard compiler/mir_to_c_conditional_branch_smoke_test_entry.gst

guard-mir-to-c-resource-metadata-smoke:
    just guard compiler/mir_to_c_resource_metadata_smoke_test_entry.gst

guard-mir-to-c-provenance-metadata-smoke:
    just guard compiler/mir_to_c_provenance_metadata_smoke_test_entry.gst

guard-mir-to-c-native-boundary-metadata-smoke:
    just guard compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst

guard-mir-to-c-return-int-literal-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling tiny MIR-to-C return literal..."
    mkdir -p build/guards/mir_to_c_return_int_literal_native
    just guard compiler/mir_to_c_return_int_literal_smoke_test_entry.gst
    generated_c="build/guards/mir_to_c_return_int_literal_native/tiny_return_int.c"
    binary="build/guards/mir_to_c_return_int_literal_native/tiny_return_int_bin"
    rg -n -F 'int tiny_return_int(void) { return 1; }' to.log >/dev/null
    printf '%s\n' 'int tiny_return_int(void) { return 1; }' > "$generated_c"
    printf '%s\n' 'int main(void) { return tiny_return_int(); }' >> "$generated_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$generated_c" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "1" ]; then
      echo "Expected tiny MIR-to-C native binary to exit with status 1, got $status"
      exit 1
    fi
    echo "✅ Tiny MIR-to-C return literal native smoke passed."

guard-mir-owned-return-int-literal-validation:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking MIR-owned validation: return int literal..."
    just guard-mir-lower-return-int-literal-smoke
    just guard-mir-to-c-return-int-literal-smoke
    just guard-mir-to-c-return-int-literal-native-smoke
    echo "✅ MIR-owned validation passed: return int literal lowers, emits C, and executes natively through MIR."

guard-mir-feature-return-int-routed-execution:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔀 Checking MIR-preferred routed execution: return int literal..."
    manifest_doc="compiler/MIR_AST_TO_C_RETIREMENT_MANIFEST.md"
    rg -n -F 'feature_name: return_int_literal' "$manifest_doc" >/dev/null
    rg -n -F 'ast_to_c_status: retired' "$manifest_doc" >/dev/null
    rg -n -F 'preferred_codegen_route: mir_to_c' "$manifest_doc" >/dev/null
    rg -n -F 'routed_execution_guard: guard-mir-feature-return-int-routed-execution' "$manifest_doc" justfile >/dev/null
    rg -n -F 'mir_owned_validation_guard: guard-mir-owned-return-int-literal-validation' "$manifest_doc" justfile >/dev/null
    just guard-mir-owned-return-int-literal-validation
    echo "✅ MIR-preferred routed execution passed: return_int_literal uses MIR-owned validation as its primary routed path."

guard-mir-owned-local-binding-read-validation:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking MIR-owned validation: local binding/read..."
    just guard-mir-lower-local-binding-read-smoke
    just guard-mir-to-c-local-binding-read-smoke
    just guard-mir-to-c-local-binding-read-native-smoke
    echo "✅ MIR-owned validation passed: local_binding_read lowers, emits C, and executes natively through MIR."

guard-mir-feature-local-binding-read-routed-execution:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔀 Checking MIR-preferred routed execution: local binding/read..."
    manifest_doc="compiler/MIR_AST_TO_C_RETIREMENT_MANIFEST.md"
    rg -n -F 'feature_name: local_binding_read' "$manifest_doc" >/dev/null
    rg -n -F 'ast_to_c_status: retired' "$manifest_doc" >/dev/null
    rg -n -F 'preferred_codegen_route: mir_to_c' "$manifest_doc" >/dev/null
    rg -n -F 'routed_execution_guard: guard-mir-feature-local-binding-read-routed-execution' "$manifest_doc" justfile >/dev/null
    rg -n -F 'mir_owned_validation_guard: guard-mir-owned-local-binding-read-validation' "$manifest_doc" justfile >/dev/null
    just guard-mir-owned-local-binding-read-validation
    echo "✅ MIR-preferred routed execution passed: local_binding_read uses MIR-owned validation as its primary routed path."

guard-mir-owned-if-else-return-int-validation:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking MIR-owned validation: if/else return int..."
    just guard-mir-lower-conditional-branch-smoke
    just guard-mir-to-c-conditional-branch-smoke
    just guard-mir-to-c-conditional-branch-native-smoke
    echo "✅ MIR-owned validation passed: if_else_return_int lowers, emits C, and executes natively through MIR."

guard-mir-feature-if-else-return-int-routed-execution:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔀 Checking MIR-preferred routed execution: if/else return int..."
    manifest_doc="compiler/MIR_AST_TO_C_RETIREMENT_MANIFEST.md"
    rg -n -F 'feature_name: if_else_return_int' "$manifest_doc" >/dev/null
    rg -n -F 'ast_to_c_status: retired' "$manifest_doc" >/dev/null
    rg -n -F 'preferred_codegen_route: mir_to_c' "$manifest_doc" >/dev/null
    rg -n -F 'routed_execution_guard: guard-mir-feature-if-else-return-int-routed-execution' "$manifest_doc" justfile >/dev/null
    rg -n -F 'mir_owned_validation_guard: guard-mir-owned-if-else-return-int-validation' "$manifest_doc" justfile >/dev/null
    just guard-mir-owned-if-else-return-int-validation
    echo "✅ MIR-preferred routed execution passed: if_else_return_int uses MIR-owned validation as its primary routed path."

guard-mir-owned-local-binding-read-provenance-metadata-validation:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking MIR-owned validation: local binding/read provenance metadata..."
    just guard-mir-lower-provenance-metadata-smoke
    just guard-mir-to-c-provenance-metadata-smoke
    just guard-mir-to-c-provenance-metadata-native-smoke
    echo "✅ MIR-owned validation passed: local_binding_read_provenance_metadata lowers, emits C, and executes natively through MIR."

guard-mir-feature-local-binding-read-provenance-metadata-routed-execution:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔀 Checking MIR-preferred routed execution: local binding/read provenance metadata..."
    manifest_doc="compiler/MIR_AST_TO_C_RETIREMENT_MANIFEST.md"
    rg -n -F 'feature_name: local_binding_read_provenance_metadata' "$manifest_doc" >/dev/null
    rg -n -F 'ast_to_c_status: retired' "$manifest_doc" >/dev/null
    rg -n -F 'preferred_codegen_route: mir_to_c' "$manifest_doc" >/dev/null
    rg -n -F 'routed_execution_guard: guard-mir-feature-local-binding-read-provenance-metadata-routed-execution' "$manifest_doc" justfile >/dev/null
    rg -n -F 'mir_owned_validation_guard: guard-mir-owned-local-binding-read-provenance-metadata-validation' "$manifest_doc" justfile >/dev/null
    just guard-mir-owned-local-binding-read-provenance-metadata-validation
    echo "✅ MIR-preferred routed execution passed: local_binding_read_provenance_metadata uses MIR-owned validation as its primary routed path."

guard-mir-to-c-block-jump-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling tiny MIR-to-C block jump..."
    mkdir -p build/guards/mir_to_c_block_jump_native
    just guard compiler/mir_to_c_block_jump_smoke_test_entry.gst
    generated_c="build/guards/mir_to_c_block_jump_native/tiny_block_jump.c"
    binary="build/guards/mir_to_c_block_jump_native/tiny_block_jump_bin"
    rg -n -F 'int tiny_block_jump(void) { goto block_1; block_1: return 1; }' to.log >/dev/null
    printf '%s\n' 'int tiny_block_jump(void) { goto block_1; block_1: return 1; }' > "$generated_c"
    printf '%s\n' 'int main(void) { return tiny_block_jump(); }' >> "$generated_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$generated_c" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "1" ]; then
      echo "Expected tiny MIR-to-C block jump native binary to exit with status 1, got $status"
      exit 1
    fi
    echo "✅ Tiny MIR-to-C block jump native smoke passed."

guard-mir-to-c-conditional-branch-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling tiny MIR-to-C conditional branch..."
    mkdir -p build/guards/mir_to_c_conditional_branch_native
    just guard compiler/mir_to_c_conditional_branch_smoke_test_entry.gst
    generated_c="build/guards/mir_to_c_conditional_branch_native/tiny_conditional_branch.c"
    binary="build/guards/mir_to_c_conditional_branch_native/tiny_conditional_branch_bin"
    rg -n -F 'int tiny_conditional_branch(void) { if (1) goto block_1; goto block_2; block_1: return 1; block_2: return 2; }' to.log >/dev/null
    printf '%s\n' 'int tiny_conditional_branch(void) { if (1) goto block_1; goto block_2; block_1: return 1; block_2: return 2; }' > "$generated_c"
    printf '%s\n' 'int main(void) { return tiny_conditional_branch(); }' >> "$generated_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$generated_c" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "1" ]; then
      echo "Expected tiny MIR-to-C conditional branch native binary to exit with status 1, got $status"
      exit 1
    fi
    echo "✅ Tiny MIR-to-C conditional branch native smoke passed."

guard-mir-to-c-resource-metadata-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling tiny MIR-to-C resource metadata fixture..."
    mkdir -p build/guards/mir_to_c_resource_metadata_native
    just guard compiler/mir_to_c_resource_metadata_smoke_test_entry.gst
    generated_c="build/guards/mir_to_c_resource_metadata_native/tiny_resource_metadata_local.c"
    binary="build/guards/mir_to_c_resource_metadata_native/tiny_resource_metadata_local_bin"
    rg -n -F 'int tiny_resource_metadata_local(void) { int value = 2; return value; }' to.log >/dev/null
    printf '%s\n' 'int tiny_resource_metadata_local(void) { int value = 2; return value; }' > "$generated_c"
    printf '%s\n' 'int main(void) { return tiny_resource_metadata_local(); }' >> "$generated_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$generated_c" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "2" ]; then
      echo "Expected tiny MIR-to-C resource metadata native binary to exit with status 2, got $status"
      exit 1
    fi
    echo "✅ Tiny MIR-to-C resource metadata native smoke passed."

guard-mir-to-c-provenance-metadata-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling tiny MIR-to-C provenance metadata fixture..."
    mkdir -p build/guards/mir_to_c_provenance_metadata_native
    just guard compiler/mir_to_c_provenance_metadata_smoke_test_entry.gst
    generated_c="build/guards/mir_to_c_provenance_metadata_native/tiny_provenance_metadata_local_read.c"
    binary="build/guards/mir_to_c_provenance_metadata_native/tiny_provenance_metadata_local_read_bin"
    rg -n -F 'int tiny_provenance_metadata_local_read(void) { int value = 2; return value; }' to.log >/dev/null
    printf '%s\n' 'int tiny_provenance_metadata_local_read(void) { int value = 2; return value; }' > "$generated_c"
    printf '%s\n' 'int main(void) { return tiny_provenance_metadata_local_read(); }' >> "$generated_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$generated_c" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "2" ]; then
      echo "Expected tiny MIR-to-C provenance metadata native binary to exit with status 2, got $status"
      exit 1
    fi
    echo "✅ Tiny MIR-to-C provenance metadata native smoke passed."

guard-mir-to-c-native-boundary-metadata-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling tiny MIR-to-C native-boundary metadata fixture..."
    mkdir -p build/guards/mir_to_c_native_boundary_metadata_native
    just guard compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst
    generated_c="build/guards/mir_to_c_native_boundary_metadata_native/tiny_native_boundary_metadata_function.c"
    binary="build/guards/mir_to_c_native_boundary_metadata_native/tiny_native_boundary_metadata_function_bin"
    rg -n -F 'void tiny_native_boundary_metadata_function(void) { return; }' to.log >/dev/null
    printf '%s\n' 'void tiny_native_boundary_metadata_function(void) { return; }' > "$generated_c"
    printf '%s\n' 'int main(void) { tiny_native_boundary_metadata_function(); return 0; }' >> "$generated_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$generated_c" -o "$binary"
    "$binary"
    echo "✅ Tiny MIR-to-C native-boundary metadata native smoke passed."

guard-mir-to-c-local-binding-read-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling tiny MIR-to-C local binding/read..."
    mkdir -p build/guards/mir_to_c_local_binding_read_native
    just guard compiler/mir_to_c_local_binding_read_smoke_test_entry.gst
    generated_c="build/guards/mir_to_c_local_binding_read_native/tiny_local_binding_read.c"
    binary="build/guards/mir_to_c_local_binding_read_native/tiny_local_binding_read_bin"
    rg -n -F 'int tiny_local_binding_read(void) { int value = 2; return value; }' to.log >/dev/null
    printf '%s\n' 'int tiny_local_binding_read(void) { int value = 2; return value; }' > "$generated_c"
    printf '%s\n' 'int main(void) { return tiny_local_binding_read(); }' >> "$generated_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$generated_c" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "2" ]; then
      echo "Expected tiny MIR-to-C local binding/read native binary to exit with status 2, got $status"
      exit 1
    fi
    echo "✅ Tiny MIR-to-C local binding/read native smoke passed."

guard-mir-to-c-tiny-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking tiny MIR-to-C surface..."
    rg -n -F 'func mir_to_c_tiny_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'gust MIR-to-C tiny fixture' compiler/mir.gst compiler/mir_to_c_entry_smoke_test_entry.gst >/dev/null
    rg -n -F 'void tiny_shell(void) { return; }' compiler/mir.gst compiler/mir_to_c_function_shell_smoke_test_entry.gst >/dev/null
    rg -n -F 'int tiny_return_int(void) { return 1; }' compiler/mir.gst compiler/mir_to_c_return_int_literal_smoke_test_entry.gst justfile >/dev/null
    rg -n -F 'int main(void) { return tiny_return_int(); }' justfile >/dev/null
    rg -n -F 'int tiny_block_jump(void) { goto block_1; block_1: return 1; }' compiler/mir.gst compiler/mir_to_c_block_jump_smoke_test_entry.gst justfile >/dev/null
    rg -n -F 'int main(void) { return tiny_block_jump(); }' justfile >/dev/null
    rg -n -F 'int tiny_conditional_branch(void) { if (1) goto block_1; goto block_2; block_1: return 1; block_2: return 2; }' compiler/mir.gst compiler/mir_to_c_conditional_branch_smoke_test_entry.gst justfile >/dev/null
    rg -n -F 'int main(void) { return tiny_conditional_branch(); }' justfile >/dev/null
    rg -n -F 'int tiny_resource_metadata_local(void) { int value = 2; return value; }' compiler/mir.gst compiler/mir_to_c_resource_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'int tiny_provenance_metadata_local_read(void) { int value = 2; return value; }' compiler/mir.gst compiler/mir_to_c_provenance_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'void tiny_native_boundary_metadata_function(void) { return; }' compiler/mir.gst compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'metadata perturbed C source' compiler/mir_to_c_resource_metadata_smoke_test_entry.gst compiler/mir_to_c_provenance_metadata_smoke_test_entry.gst compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir to c entry smoke' compiler/mir_to_c_entry_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir to c function shell smoke' compiler/mir_to_c_function_shell_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir to c return int literal smoke' compiler/mir_to_c_return_int_literal_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir to c block jump smoke' compiler/mir_to_c_block_jump_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir to c conditional branch smoke' compiler/mir_to_c_conditional_branch_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir to c resource metadata smoke' compiler/mir_to_c_resource_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir to c provenance metadata smoke' compiler/mir_to_c_provenance_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir to c native boundary metadata smoke' compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'guard-mir-to-c-entry-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-function-shell-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-return-int-literal-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-return-int-literal-native-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-block-jump-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-block-jump-native-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-conditional-branch-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-conditional-branch-native-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-resource-metadata-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-provenance-metadata-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-native-boundary-metadata-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-provenance-metadata-native-smoke' justfile >/dev/null
    rg -n -F 'compiler/mir_to_c_entry_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_to_c_function_shell_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_to_c_return_int_literal_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_to_c_block_jump_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_to_c_conditional_branch_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_to_c_resource_metadata_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_to_c_provenance_metadata_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst' justfile >/dev/null
    unexpected_mir_to_c_refs="$(rg -n -F 'mir_to_c_' compiler/*.gst | rg -v 'compiler/mir.gst:|compiler/mir_to_c_entry_smoke_test_entry.gst:|compiler/mir_to_c_function_shell_smoke_test_entry.gst:|compiler/mir_to_c_return_int_literal_smoke_test_entry.gst:|compiler/mir_to_c_local_binding_read_smoke_test_entry.gst:|compiler/mir_to_c_block_jump_smoke_test_entry.gst:|compiler/mir_to_c_conditional_branch_smoke_test_entry.gst:|compiler/mir_to_c_resource_metadata_smoke_test_entry.gst:|compiler/mir_to_c_provenance_metadata_smoke_test_entry.gst:|compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst:' || true)"
    if [ -n "$unexpected_mir_to_c_refs" ]; then
      echo "Unexpected MIR-to-C reference outside fixture-only files:"
      echo "$unexpected_mir_to_c_refs"
      exit 1
    fi
    forbidden_refs="$(rg -n -F 'MirStmt.LocalSet' compiler/mir_to_c_entry_smoke_test_entry.gst compiler/mir_to_c_function_shell_smoke_test_entry.gst compiler/mir_to_c_return_int_literal_smoke_test_entry.gst || true)"
    if [ -n "$forbidden_refs" ]; then
      echo "Tiny MIR-to-C fixtures must not cover locals/statements yet:"
      echo "$forbidden_refs"
      exit 1
    fi
    if rg -n -F 'MirTerminator.Branch' compiler/mir_to_c_entry_smoke_test_entry.gst compiler/mir_to_c_function_shell_smoke_test_entry.gst compiler/mir_to_c_return_int_literal_smoke_test_entry.gst >/dev/null; then
      echo "Tiny MIR-to-C fixtures must not cover branches yet."
      exit 1
    fi
    if rg -n -F 'MirValue.Call' compiler/mir_to_c_entry_smoke_test_entry.gst compiler/mir_to_c_function_shell_smoke_test_entry.gst compiler/mir_to_c_return_int_literal_smoke_test_entry.gst >/dev/null; then
      echo "Tiny MIR-to-C fixtures must not cover calls yet."
      exit 1
    fi
    echo "✅ Tiny MIR-to-C surface guard passed."

guard-mir-feature-harness-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking MIR feature migration harness surface..."
    harness_doc="compiler/MIR_FEATURE_MIGRATION_HARNESS.md"
    registry_doc="compiler/MIR_FEATURE_MIGRATION_REGISTRY.md"
    if [ ! -f "$harness_doc" ]; then
      echo "Missing $harness_doc. Phase 5 requires the harness contract file."
      exit 1
    fi
    if [ ! -f "$registry_doc" ]; then
      echo "Missing $registry_doc. Step 3 requires the MIR feature migration registry."
      exit 1
    fi
    rg -n -F 'MIR_FEATURE_MIGRATION_HARNESS_VERSION: 1' "$harness_doc" >/dev/null
    rg -n -F 'MIR_FEATURE_MIGRATION_PHASE: phase7-provenance-metadata-preservation-entry' "$harness_doc" >/dev/null
    rg -n -F 'MIR_FEATURE_MIGRATION_NO_FEATURES_MIGRATED: false' "$harness_doc" >/dev/null
    rg -n -F 'MIR_FEATURE_MIGRATION_REGISTRY: compiler/MIR_FEATURE_MIGRATION_REGISTRY.md' "$harness_doc" >/dev/null
    rg -n -F 'MIR_AST_TO_C_RETIREMENT_MANIFEST: compiler/MIR_AST_TO_C_RETIREMENT_MANIFEST.md' "$harness_doc" >/dev/null
    rg -n -F 'source Gust fixture' "$harness_doc" >/dev/null
    rg -n -F 'old AST-to-C expected behavior' "$harness_doc" >/dev/null
    rg -n -F 'MIR lowering' "$harness_doc" >/dev/null
    rg -n -F 'MIR verifier or focused MIR structural invariant guard' "$harness_doc" >/dev/null
    rg -n -F 'MIR-to-C' "$harness_doc" >/dev/null
    rg -n -F 'native execution' "$harness_doc" >/dev/null
    rg -n -F 'feature_name' "$harness_doc" >/dev/null
    rg -n -F 'source_fixture' "$harness_doc" >/dev/null
    rg -n -F 'old_behavior_guard' "$harness_doc" >/dev/null
    rg -n -F 'mir_lowering_guard' "$harness_doc" >/dev/null
    rg -n -F 'mir_verifier_guard' "$harness_doc" >/dev/null
    rg -n -F 'mir_to_c_guard' "$harness_doc" >/dev/null
    rg -n -F 'native_execution_guard' "$harness_doc" >/dev/null
    rg -n -F 'expected_behavior' "$harness_doc" >/dev/null
    rg -n -F 'return_int_literal' "$harness_doc" "$registry_doc" >/dev/null
    rg -n -F 'local_binding_read' "$harness_doc" "$registry_doc" >/dev/null
    rg -n -F 'if_else_return_int' "$harness_doc" "$registry_doc" >/dev/null
    rg -n -F 'local_binding_read_provenance_metadata' "$harness_doc" "$registry_doc" >/dev/null
    rg -n -F 'compiler/mir_feature_return_int_preservation_source.gst' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-feature-return-int-preservation' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-lower-return-int-literal-smoke' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-return-int-literal-smoke' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-return-int-literal-native-smoke' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'compiler/mir_feature_local_binding_read_preservation_source.gst' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-feature-local-binding-read-preservation' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-lower-local-binding-read-smoke' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-local-binding-read-smoke' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-local-binding-read-native-smoke' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'compiler/mir_feature_if_else_return_int_preservation_source.gst' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-feature-if-else-return-int-preservation' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-lower-conditional-branch-smoke' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-conditional-branch-smoke' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-conditional-branch-native-smoke' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-feature-local-binding-read-provenance-metadata-preservation' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-lower-provenance-metadata-smoke' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-provenance-metadata-smoke' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-provenance-metadata-native-smoke' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'native executable exits with status `1`' "$harness_doc" >/dev/null
    rg -n -F 'native executable exits with status `2`' "$harness_doc" >/dev/null
    rg -n -F 'expected_behavior: native executable exits with status 1' "$registry_doc" >/dev/null
    rg -n -F 'expected_behavior: native executable exits with status 2' "$registry_doc" >/dev/null
    just guard-mir-feature-registry-surface
    echo "✅ MIR feature migration harness surface guard passed."

guard-mir-feature-migration-registry:
    just guard-mir-feature-registry-surface

guard-mir-ast-to-c-retirement-manifest-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking MIR AST-to-C retirement manifest surface..."
    manifest_doc="compiler/MIR_AST_TO_C_RETIREMENT_MANIFEST.md"
    registry_doc="compiler/MIR_FEATURE_MIGRATION_REGISTRY.md"
    if [ ! -f "$manifest_doc" ]; then
      echo "Missing $manifest_doc. Phase 8 requires the AST-to-C retirement manifest."
      exit 1
    fi
    rg -n -F 'MIR_AST_TO_C_RETIREMENT_MANIFEST_VERSION: 1' "$manifest_doc" >/dev/null
    rg -n -F 'MIR_AST_TO_C_RETIREMENT_MANIFEST_PHASE: phase8-provenance-metadata-ast-to-c-retired-entry' "$manifest_doc" >/dev/null
    rg -n -F 'MIR_AST_TO_C_RETIREMENT_MANIFEST_ENTRY_COUNT: 4' "$manifest_doc" >/dev/null
    rg -n -F 'MIR_FEATURE_MIGRATION_REGISTRY: compiler/MIR_FEATURE_MIGRATION_REGISTRY.md' "$manifest_doc" >/dev/null
    rg -n -F 'still_required' "$manifest_doc" >/dev/null
    rg -n -F 'retirement_candidate' "$manifest_doc" >/dev/null
    rg -n -F 'retired' "$manifest_doc" >/dev/null
    rg -n -F 'ast_to_c_status' "$manifest_doc" >/dev/null
    rg -n -F 'retirement_note' "$manifest_doc" >/dev/null
    rg -n -F 'mir_owned_validation_guard' "$manifest_doc" >/dev/null
    rg -n -F 'preferred_codegen_route' "$manifest_doc" >/dev/null
    rg -n -F 'routed_execution_guard' "$manifest_doc" >/dev/null
    rg -n -F 'mir_owned_validation_guard: guard-mir-owned-return-int-literal-validation' "$manifest_doc" justfile >/dev/null
    rg -n -F 'mir_owned_validation_guard: guard-mir-owned-local-binding-read-validation' "$manifest_doc" justfile >/dev/null
    rg -n -F 'mir_owned_validation_guard: guard-mir-owned-if-else-return-int-validation' "$manifest_doc" justfile >/dev/null
    rg -n -F 'mir_owned_validation_guard: guard-mir-owned-local-binding-read-provenance-metadata-validation' "$manifest_doc" justfile >/dev/null
    rg -n -F 'preferred_codegen_route: mir_to_c' "$manifest_doc" >/dev/null
    rg -n -F 'routed_execution_guard: guard-mir-feature-return-int-routed-execution' "$manifest_doc" justfile >/dev/null
    rg -n -F 'routed_execution_guard: guard-mir-feature-local-binding-read-routed-execution' "$manifest_doc" justfile >/dev/null
    rg -n -F 'routed_execution_guard: guard-mir-feature-if-else-return-int-routed-execution' "$manifest_doc" justfile >/dev/null
    rg -n -F 'routed_execution_guard: guard-mir-feature-local-binding-read-provenance-metadata-routed-execution' "$manifest_doc" justfile >/dev/null
    rg -n -F 'feature_name: return_int_literal' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'feature_name: local_binding_read' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'feature_name: if_else_return_int' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'feature_name: local_binding_read_provenance_metadata' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'source_fixture: compiler/mir_feature_return_int_preservation_source.gst' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'source_fixture: compiler/mir_feature_local_binding_read_preservation_source.gst' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'source_fixture: compiler/mir_feature_if_else_return_int_preservation_source.gst' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'source_fixture: compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'old_behavior_guard: guard-mir-feature-return-int-preservation' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'mir_lowering_guard: guard-mir-lower-return-int-literal-smoke' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'mir_to_c_guard: guard-mir-to-c-return-int-literal-smoke' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'native_execution_guard: guard-mir-to-c-return-int-literal-native-smoke' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'old_behavior_guard: guard-mir-feature-local-binding-read-preservation' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'mir_lowering_guard: guard-mir-lower-local-binding-read-smoke' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'mir_to_c_guard: guard-mir-to-c-local-binding-read-smoke' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'native_execution_guard: guard-mir-to-c-local-binding-read-native-smoke' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'old_behavior_guard: guard-mir-feature-if-else-return-int-preservation' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'mir_lowering_guard: guard-mir-lower-conditional-branch-smoke' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'mir_to_c_guard: guard-mir-to-c-conditional-branch-smoke' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'native_execution_guard: guard-mir-to-c-conditional-branch-native-smoke' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'old_behavior_guard: guard-mir-feature-local-binding-read-provenance-metadata-preservation' "$manifest_doc" "$registry_doc" >/dev/null
    status_count="$( (rg -n -F 'ast_to_c_status: still_required' "$manifest_doc" || true) | wc -l | tr -d '[:space:]')"
    if [ "$status_count" != "0" ]; then
      echo "Expected zero still_required AST-to-C retirement manifest entries after retiring all Phase 8 entries, found $status_count."
      rg -n -F 'ast_to_c_status:' "$manifest_doc" || true
      exit 1
    fi
    candidate_entries="$(rg -n -F 'ast_to_c_status: retirement_candidate' "$manifest_doc" || true)"
    if [ -n "$candidate_entries" ]; then
      echo "Pre-step 2 must not leave entries as retirement_candidate:"
      echo "$candidate_entries"
      exit 1
    fi
    retired_count="$(rg -n -F 'ast_to_c_status: retired' "$manifest_doc" | wc -l | tr -d '[:space:]')"
    if [ "$retired_count" != "4" ]; then
      echo "Expected exactly four retired AST-to-C retirement manifest entries, found $retired_count."
      rg -n -F 'ast_to_c_status:' "$manifest_doc" || true
      exit 1
    fi
    rg -n -F 'feature_name: return_int_literal' "$manifest_doc" >/dev/null
    rg -n -F 'feature_name: local_binding_read' "$manifest_doc" >/dev/null
    rg -n -F 'feature_name: if_else_return_int' "$manifest_doc" >/dev/null
    rg -n -F 'feature_name: local_binding_read_provenance_metadata' "$manifest_doc" >/dev/null
    rg -n -F 'mir_owned_validation_guard: guard-mir-owned-return-int-literal-validation' "$manifest_doc" justfile >/dev/null
    rg -n -F 'mir_owned_validation_guard: guard-mir-owned-local-binding-read-validation' "$manifest_doc" justfile >/dev/null
    rg -n -F 'mir_owned_validation_guard: guard-mir-owned-if-else-return-int-validation' "$manifest_doc" justfile >/dev/null
    rg -n -F 'mir_owned_validation_guard: guard-mir-owned-local-binding-read-provenance-metadata-validation' "$manifest_doc" justfile >/dev/null
    rg -n -F 'preferred_codegen_route: mir_to_c' "$manifest_doc" >/dev/null
    rg -n -F 'routed_execution_guard: guard-mir-feature-return-int-routed-execution' "$manifest_doc" justfile >/dev/null
    rg -n -F 'routed_execution_guard: guard-mir-feature-local-binding-read-routed-execution' "$manifest_doc" justfile >/dev/null
    rg -n -F 'routed_execution_guard: guard-mir-feature-if-else-return-int-routed-execution' "$manifest_doc" justfile >/dev/null
    rg -n -F 'routed_execution_guard: guard-mir-feature-local-binding-read-provenance-metadata-routed-execution' "$manifest_doc" justfile >/dev/null
    rg -n -F 'ast_to_c_status: retired' "$manifest_doc" >/dev/null
    rg -n -F 'retired this feature from primary AST-to-C validation' "$manifest_doc" >/dev/null
    rg -n -F 'retired local_binding_read from primary AST-to-C validation' "$manifest_doc" >/dev/null
    rg -n -F 'retired if_else_return_int from primary AST-to-C validation' "$manifest_doc" >/dev/null
    rg -n -F 'retired local_binding_read_provenance_metadata from primary AST-to-C validation' "$manifest_doc" >/dev/null

    local_binding_routed_body="$(awk '/^guard-mir-feature-local-binding-read-routed-execution:/{flag=1} /^guard-mir-owned-if-else-return-int-validation:/{flag=0} flag{print}' justfile)"
    if printf '%s\n' "$local_binding_routed_body" | rg -n -F 'if_else_return_int' >/dev/null; then
      echo "local_binding_read routed guard must not check if_else_return_int manifest fields."
      exit 1
    fi
    if printf '%s\n' "$local_binding_routed_body" | rg -n -F 'guard-mir-feature-if-else-return-int-routed-execution' >/dev/null; then
      echo "local_binding_read routed guard must not reference the if_else_return_int routed guard."
      exit 1
    fi
    if printf '%s\n' "$local_binding_routed_body" | rg -n -F 'guard-mir-owned-if-else-return-int-validation' >/dev/null; then
      echo "local_binding_read routed guard must not reference the if_else_return_int MIR-owned guard."
      exit 1
    fi

    suite_body="$(sed -n '/^guard-mir-feature-migration-suite:/,/^guard-test-runner-bounded-concurrency-surface:/p' justfile)"
    printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-feature-return-int-routed-execution' >/dev/null
    printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-feature-local-binding-read-routed-execution' >/dev/null
    printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-feature-if-else-return-int-routed-execution' >/dev/null
    printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-feature-local-binding-read-provenance-metadata-routed-execution' >/dev/null
    if printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-feature-return-int-preservation' >/dev/null; then
      echo "return_int_literal old AST-to-C preservation guard must be retired from the primary migration suite."
      exit 1
    fi
    if printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-feature-local-binding-read-preservation' >/dev/null; then
      echo "local_binding_read old AST-to-C preservation guard must be retired from the primary migration suite."
      exit 1
    fi
    if printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-feature-if-else-return-int-preservation' >/dev/null; then
      echo "if_else_return_int old AST-to-C preservation guard must be retired from the primary migration suite."
      exit 1
    fi
    if printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-feature-local-binding-read-provenance-metadata-preservation' >/dev/null; then
      echo "local_binding_read_provenance_metadata old AST-to-C preservation guard must be retired from the primary migration suite."
      exit 1
    fi
    echo "✅ MIR AST-to-C retirement manifest surface guard passed."

guard-mir-feature-registry-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking MIR feature migration registry surface..."
    registry_doc="compiler/MIR_FEATURE_MIGRATION_REGISTRY.md"
    if [ ! -f "$registry_doc" ]; then
      echo "Missing $registry_doc. Step 3 requires the MIR feature migration registry."
      exit 1
    fi
    rg -n -F 'MIR_FEATURE_MIGRATION_REGISTRY_VERSION: 1' "$registry_doc" >/dev/null
    rg -n -F 'MIR_FEATURE_MIGRATION_REGISTRY_PHASE: phase7-provenance-metadata-preservation-entry' "$registry_doc" >/dev/null
    rg -n -F 'MIR_FEATURE_MIGRATION_REGISTRY_ENTRY_COUNT: 4' "$registry_doc" >/dev/null
    rg -n -F 'feature_name' "$registry_doc" >/dev/null
    rg -n -F 'source_fixture' "$registry_doc" >/dev/null
    rg -n -F 'old_behavior_guard' "$registry_doc" >/dev/null
    rg -n -F 'mir_lowering_guard' "$registry_doc" >/dev/null
    rg -n -F 'mir_verifier_guard' "$registry_doc" >/dev/null
    rg -n -F 'mir_to_c_guard' "$registry_doc" >/dev/null
    rg -n -F 'native_execution_guard' "$registry_doc" >/dev/null
    rg -n -F 'expected_behavior' "$registry_doc" >/dev/null
    rg -n -F 'feature_name: return_int_literal' "$registry_doc" >/dev/null
    rg -n -F 'source_fixture: compiler/mir_feature_return_int_preservation_source.gst' "$registry_doc" >/dev/null
    rg -n -F 'old_behavior_guard: guard-mir-feature-return-int-preservation' "$registry_doc" >/dev/null
    rg -n -F 'mir_lowering_guard: guard-mir-lower-return-int-literal-smoke' "$registry_doc" >/dev/null
    rg -n -F 'mir_verifier_guard: guard-mir-lower-return-int-literal-smoke' "$registry_doc" >/dev/null
    rg -n -F 'mir_to_c_guard: guard-mir-to-c-return-int-literal-smoke' "$registry_doc" >/dev/null
    rg -n -F 'native_execution_guard: guard-mir-to-c-return-int-literal-native-smoke' "$registry_doc" >/dev/null
    rg -n -F 'expected_behavior: native executable exits with status 1' "$registry_doc" >/dev/null
    rg -n -F 'feature_name: local_binding_read' "$registry_doc" >/dev/null
    rg -n -F 'source_fixture: compiler/mir_feature_local_binding_read_preservation_source.gst' "$registry_doc" >/dev/null
    rg -n -F 'old_behavior_guard: guard-mir-feature-local-binding-read-preservation' "$registry_doc" >/dev/null
    rg -n -F 'mir_lowering_guard: guard-mir-lower-local-binding-read-smoke' "$registry_doc" >/dev/null
    rg -n -F 'mir_verifier_guard: guard-mir-lower-local-binding-read-smoke' "$registry_doc" >/dev/null
    rg -n -F 'mir_to_c_guard: guard-mir-to-c-local-binding-read-smoke' "$registry_doc" >/dev/null
    rg -n -F 'native_execution_guard: guard-mir-to-c-local-binding-read-native-smoke' "$registry_doc" >/dev/null
    rg -n -F 'expected_behavior: native executable exits with status 2' "$registry_doc" >/dev/null
    rg -n -F 'feature_name: if_else_return_int' "$registry_doc" >/dev/null
    rg -n -F 'source_fixture: compiler/mir_feature_if_else_return_int_preservation_source.gst' "$registry_doc" >/dev/null
    rg -n -F 'old_behavior_guard: guard-mir-feature-if-else-return-int-preservation' "$registry_doc" >/dev/null
    rg -n -F 'mir_lowering_guard: guard-mir-lower-conditional-branch-smoke' "$registry_doc" >/dev/null
    rg -n -F 'mir_verifier_guard: guard-mir-lower-conditional-branch-smoke' "$registry_doc" >/dev/null
    rg -n -F 'mir_to_c_guard: guard-mir-to-c-conditional-branch-smoke' "$registry_doc" >/dev/null
    rg -n -F 'native_execution_guard: guard-mir-to-c-conditional-branch-native-smoke' "$registry_doc" >/dev/null
    rg -n -F 'feature_name: local_binding_read_provenance_metadata' "$registry_doc" >/dev/null
    rg -n -F 'source_fixture: compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst' "$registry_doc" >/dev/null
    rg -n -F 'old_behavior_guard: guard-mir-feature-local-binding-read-provenance-metadata-preservation' "$registry_doc" >/dev/null
    rg -n -F 'mir_lowering_guard: guard-mir-lower-provenance-metadata-smoke' "$registry_doc" >/dev/null
    rg -n -F 'mir_verifier_guard: guard-mir-lower-provenance-metadata-smoke' "$registry_doc" >/dev/null
    rg -n -F 'mir_to_c_guard: guard-mir-to-c-provenance-metadata-smoke' "$registry_doc" >/dev/null
    rg -n -F 'native_execution_guard: guard-mir-to-c-provenance-metadata-native-smoke' "$registry_doc" >/dev/null
    rg -n -F 'compiler/mir_feature_return_int_preservation_source.gst' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-feature-return-int-preservation' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-lower-return-int-literal-smoke' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-return-int-literal-smoke' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-return-int-literal-native-smoke' "$registry_doc" justfile >/dev/null
    rg -n -F 'compiler/mir_feature_local_binding_read_preservation_source.gst' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-feature-local-binding-read-preservation' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-lower-local-binding-read-smoke' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-local-binding-read-smoke' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-local-binding-read-native-smoke' "$registry_doc" justfile >/dev/null
    rg -n -F 'compiler/mir_feature_if_else_return_int_preservation_source.gst' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-feature-if-else-return-int-preservation' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-lower-conditional-branch-smoke' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-conditional-branch-smoke' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-conditional-branch-native-smoke' "$registry_doc" justfile >/dev/null
    rg -n -F 'compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-feature-local-binding-read-provenance-metadata-preservation' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-lower-provenance-metadata-smoke' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-provenance-metadata-smoke' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-provenance-metadata-native-smoke' "$registry_doc" justfile >/dev/null
    echo "✅ MIR feature migration registry surface guard passed."

guard-mir-to-c-boring-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking MIR-to-C boring surface before Cranelift..."
    manifest_doc="compiler/MIR_AST_TO_C_RETIREMENT_MANIFEST.md"
    registry_doc="compiler/MIR_FEATURE_MIGRATION_REGISTRY.md"
    just guard-mir-ast-to-c-retirement-manifest-surface

    rg -n -F 'MIR_AST_TO_C_RETIREMENT_MANIFEST_PHASE: phase8-provenance-metadata-ast-to-c-retired-entry' "$manifest_doc" >/dev/null
    rg -n -F 'MIR_AST_TO_C_RETIREMENT_MANIFEST_ENTRY_COUNT: 4' "$manifest_doc" >/dev/null

    still_required_count="$( (rg -n -F 'ast_to_c_status: still_required' "$manifest_doc" || true) | wc -l | tr -d '[:space:]')"
    if [ "$still_required_count" != "0" ]; then
      echo "MIR-to-C boring gate requires zero still_required manifest entries, found $still_required_count."
      rg -n -F 'ast_to_c_status:' "$manifest_doc" || true
      exit 1
    fi

    candidate_entries="$(rg -n -F 'ast_to_c_status: retirement_candidate' "$manifest_doc" || true)"
    if [ -n "$candidate_entries" ]; then
      echo "MIR-to-C boring gate requires zero retirement_candidate manifest entries:"
      echo "$candidate_entries"
      exit 1
    fi

    retired_count="$(rg -n -F 'ast_to_c_status: retired' "$manifest_doc" | wc -l | tr -d '[:space:]')"
    if [ "$retired_count" != "4" ]; then
      echo "MIR-to-C boring gate requires exactly four retired manifest entries, found $retired_count."
      rg -n -F 'ast_to_c_status:' "$manifest_doc" || true
      exit 1
    fi

    rg -n -F 'feature_name: return_int_literal' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'feature_name: local_binding_read' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'feature_name: if_else_return_int' "$manifest_doc" "$registry_doc" >/dev/null
    rg -n -F 'feature_name: local_binding_read_provenance_metadata' "$manifest_doc" "$registry_doc" >/dev/null

    rg -n -F 'mir_owned_validation_guard: guard-mir-owned-return-int-literal-validation' "$manifest_doc" justfile >/dev/null
    rg -n -F 'mir_owned_validation_guard: guard-mir-owned-local-binding-read-validation' "$manifest_doc" justfile >/dev/null
    rg -n -F 'mir_owned_validation_guard: guard-mir-owned-if-else-return-int-validation' "$manifest_doc" justfile >/dev/null
    rg -n -F 'mir_owned_validation_guard: guard-mir-owned-local-binding-read-provenance-metadata-validation' "$manifest_doc" justfile >/dev/null

    rg -n -F 'routed_execution_guard: guard-mir-feature-return-int-routed-execution' "$manifest_doc" justfile >/dev/null
    rg -n -F 'routed_execution_guard: guard-mir-feature-local-binding-read-routed-execution' "$manifest_doc" justfile >/dev/null
    rg -n -F 'routed_execution_guard: guard-mir-feature-if-else-return-int-routed-execution' "$manifest_doc" justfile >/dev/null
    rg -n -F 'routed_execution_guard: guard-mir-feature-local-binding-read-provenance-metadata-routed-execution' "$manifest_doc" justfile >/dev/null

    rg -n -F 'guard-mir-feature-return-int-preservation:' justfile >/dev/null
    rg -n -F 'guard-mir-feature-local-binding-read-preservation:' justfile >/dev/null
    rg -n -F 'guard-mir-feature-if-else-return-int-preservation:' justfile >/dev/null
    rg -n -F 'guard-mir-feature-local-binding-read-provenance-metadata-preservation:' justfile >/dev/null

    suite_body="$(sed -n '/^guard-mir-feature-migration-suite:/,/^guard-test-runner-bounded-concurrency-surface:/p' justfile)"
    printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-owned-return-int-literal-validation' >/dev/null
    printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-feature-return-int-routed-execution' >/dev/null
    printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-owned-local-binding-read-validation' >/dev/null
    printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-feature-local-binding-read-routed-execution' >/dev/null
    printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-owned-if-else-return-int-validation' >/dev/null
    printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-feature-if-else-return-int-routed-execution' >/dev/null
    printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-owned-local-binding-read-provenance-metadata-validation' >/dev/null
    printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-feature-local-binding-read-provenance-metadata-routed-execution' >/dev/null

    if printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-feature-return-int-preservation' >/dev/null; then
      echo "MIR-to-C boring gate forbids return_int_literal AST-to-C preservation in the primary migration suite."
      exit 1
    fi
    if printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-feature-local-binding-read-preservation' >/dev/null; then
      echo "MIR-to-C boring gate forbids local_binding_read AST-to-C preservation in the primary migration suite."
      exit 1
    fi
    if printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-feature-if-else-return-int-preservation' >/dev/null; then
      echo "MIR-to-C boring gate forbids if_else_return_int AST-to-C preservation in the primary migration suite."
      exit 1
    fi
    if printf '%s\n' "$suite_body" | rg -n -F 'just guard-mir-feature-local-binding-read-provenance-metadata-preservation' >/dev/null; then
      echo "MIR-to-C boring gate forbids local_binding_read_provenance_metadata AST-to-C preservation in the primary migration suite."
      exit 1
    fi

    cranelift_recipe_wiring="$(just --list | rg -n -i '(^|[[:space:]])(guard-.*cranelift|cranelift[-_:])' | rg -v -F 'guard-cranelift-experiment-manifest-surface' | rg -v -F 'guard-cranelift-backend-surface' | rg -v -F 'guard-cranelift-dependency-beachhead' | rg -v -F 'guard-cranelift-experimental-backend-suite' | rg -v -F 'guard-cranelift-no-fixture-regression' | rg -v -F 'guard-cranelift-return-int-native-smoke' | rg -v -F 'guard-cranelift-local-binding-native-smoke' | rg -v -F 'guard-cranelift-local-binding-read-native-smoke' | rg -v -F 'guard-cranelift-conditional-branch-native-smoke' | rg -v -F 'guard-cranelift-branch-native-smoke' | rg -v -F 'guard-cranelift-identity-i32-native-smoke' | rg -v -F 'guard-cranelift-mir-to-c-differential-native-smoke' | rg -v -F 'guard-cranelift-differential-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-add-i32-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-positive-i32-branch-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-increment-local-i32-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-call-helper-i32-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-extern-call-i32-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-extern-add-i32-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-extern-predicate-branch-i32-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-mir-return-int-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-mir-local-binding-read-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-mir-conditional-branch-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-mir-add-i32-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-mir-positive-i32-branch-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-mir-increment-local-i32-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-mir-call-helper-i32-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-mir-extern-call-i32-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-mir-extern-add-i32-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-mir-extern-predicate-branch-i32-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-return-int-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-local-binding-read-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-conditional-branch-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-ingestion-invalid-fixtures-native-rejection' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-ingestion-corpus-surface' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-add-i32-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-provenance-metadata-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-resource-metadata-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-native-boundary-metadata-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-positive-i32-branch-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-block-jump-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-block-local-branch-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-block-two-local-update-branch-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-block-local-branch-join-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-block-param-update-branch-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-block-param-local-call-branch-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-block-param-imported-call-branch-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-block-param-imported-call-return-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-block-param-imported-predicate-update-branch-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-block-param-merge-update-branch-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-block-param-merge-imported-call-return-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-block-param-merge-arm-update-imported-call-return-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-block-param-merge-arm-update-imported-call-branch-ingestion-native-smoke' || true)"
    cranelift_recipe_wiring="$(printf '%s\n' "$cranelift_recipe_wiring" | rg -v -F 'guard-cranelift-compiler-mir-block-param-merge-imported-branch-joined-return-ingestion-native-smoke' || true)"
    if [ -n "$cranelift_recipe_wiring" ]; then
      echo "MIR-to-C boring gate allows only manifest, inert backend, dependency beachhead, explicit backend suite, return-int/local-binding/branch native smokes, and differential Cranelift guards before backend implementation expands."
      echo "$cranelift_recipe_wiring"
      exit 1
    fi

    cranelift_refs="$(rg -n -i -F 'cranelift' compiler src tests Cargo.toml Cargo.lock Makefile 2>/dev/null | rg -v '^compiler/CRANELIFT_EXPERIMENT_MANIFEST\.md:' | rg -v '^compiler/experiments/cranelift/' || true)"
    if [ -n "$cranelift_refs" ]; then
      echo "MIR-to-C boring gate allows only the manifest and isolated experimental Cranelift crate before production implementation references exist:"
      echo "$cranelift_refs"
      exit 1
    fi

    just guard-mir-to-c-return-int-literal-native-smoke
    just guard-mir-to-c-local-binding-read-native-smoke
    just guard-mir-to-c-conditional-branch-native-smoke
    just guard-mir-to-c-provenance-metadata-native-smoke
    echo "✅ MIR-to-C boring surface passed: all Phase 8 entries are retired, suite routing is MIR-owned, and only isolated Cranelift experiment lanes are allowed."

guard-cranelift-experiment-guard-wiring-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Cranelift experiment guard wiring inventory..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    if [ ! -f "$manifest_doc" ]; then
      echo "Missing $manifest_doc. Phase 9 requires the Cranelift experiment manifest before guard wiring can be checked."
      exit 1
    fi
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_GUARD_WIRING_SURFACE: guard-cranelift-experiment-guard-wiring-surface' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_guard_wiring_inventory_source: compiler/CRANELIFT_EXPERIMENT_MANIFEST.md' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_guard_wiring_recipe_inventory: just --summary' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_guard_wiring_native_suite_source: CRANELIFT_EXPERIMENT_ALLOWED_*_NATIVE_GUARD' "$manifest_doc" >/dev/null
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    just --summary | tr ' ' '\n' | rg '^guard-cranelift-' | sort -u > "$tmpdir/defined"
    rg --no-line-number -o 'guard-cranelift-[A-Za-z0-9_-]+' "$manifest_doc" | sort -u > "$tmpdir/manifest"
    {
      printf '%s\n' 'guard-cranelift-experiment-guard-wiring-surface'
      printf '%s\n' 'guard-cranelift-experiment-manifest-surface'
      printf '%s\n' 'guard-cranelift-backend-surface'
      printf '%s\n' 'guard-cranelift-dependency-beachhead'
      printf '%s\n' 'guard-cranelift-experimental-backend-suite'
      printf '%s\n' 'guard-cranelift-no-fixture-regression'
    } | sort -u > "$tmpdir/core"
    cat "$tmpdir/core" "$tmpdir/manifest" | sort -u > "$tmpdir/allowed"
    missing_manifest_recipes="$(comm -23 "$tmpdir/manifest" "$tmpdir/defined" || true)"
    if [ -n "$missing_manifest_recipes" ]; then
      echo "Cranelift manifest names guard recipes that are not defined in justfile:"
      echo "$missing_manifest_recipes"
      exit 1
    fi
    unexpected_cranelift_recipes="$(comm -23 "$tmpdir/defined" "$tmpdir/allowed" || true)"
    if [ -n "$unexpected_cranelift_recipes" ]; then
      echo "Cranelift guard recipes must be listed in compiler/CRANELIFT_EXPERIMENT_MANIFEST.md or be core surface guards:"
      echo "$unexpected_cranelift_recipes"
      exit 1
    fi
    native_guard_tokens="$(awk '/^CRANELIFT_EXPERIMENT_ALLOWED_.*NATIVE_GUARD: guard-cranelift-/ { print $2 }' "$manifest_doc" | awk '!seen[$0]++')"
    if [ -z "$native_guard_tokens" ]; then
      echo "Expected at least one CRANELIFT_EXPERIMENT_ALLOWED_*_NATIVE_GUARD token in $manifest_doc."
      exit 1
    fi
    while IFS= read -r guard_recipe; do
      if [ -z "$guard_recipe" ]; then
        continue
      fi
      rg -n -F "$guard_recipe:" justfile >/dev/null
    done <<< "$native_guard_tokens"
    echo "✅ Cranelift experiment guard wiring inventory passed."

guard-cranelift-experiment-manifest-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Cranelift experiment manifest surface..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    if [ ! -f "$manifest_doc" ]; then
      echo "Missing $manifest_doc. Phase 9 Step 1 requires a manifest-only Cranelift experiment contract."
      exit 1
    fi
    rg -n -F 'CRANELIFT_EXPERIMENT_MANIFEST_VERSION: 1' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ENABLED_BY_DEFAULT: false' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_CODEGEN_STATUS: return_int_local_binding_branch_differential_fixture_only' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_BACKEND_SURFACE_STATUS: differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_PRIMARY_ROUTE: mir_to_c' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_GUARD: guard-cranelift-experiment-manifest-surface' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_BACKEND_SURFACE_GUARD: guard-cranelift-backend-surface' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_DEPENDENCY_GUARD: guard-cranelift-dependency-beachhead' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_BACKEND_SUITE_GUARD: guard-cranelift-experimental-backend-suite' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_NO_FIXTURE_REGRESSION_GUARD: guard-cranelift-no-fixture-regression' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_GUARD_WIRING_SURFACE: guard-cranelift-experiment-guard-wiring-surface' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_INGESTION_CORPUS_SURFACE_GUARD: guard-cranelift-compiler-mir-ingestion-corpus-surface' "$manifest_doc" justfile >/dev/null
    just guard-cranelift-compiler-mir-ingestion-corpus-surface
    just guard-cranelift-experiment-guard-wiring-surface
    cranelift_refs="$(rg -n -i -F 'cranelift' compiler src tests Cargo.toml Cargo.lock Makefile 2>/dev/null | rg -v '^compiler/CRANELIFT_EXPERIMENT_MANIFEST\.md:' | rg -v '^compiler/experiments/cranelift/' || true)"
    if [ -n "$cranelift_refs" ]; then
      echo "Phase 9 Step 1 must not add Cranelift implementation references:"
      echo "$cranelift_refs"
      exit 1
    fi
    echo "✅ Cranelift experiment manifest surface passed: dependency beachhead plus explicit backend suite, manifest-derived guard wiring, disabled by default, and no production codegen exists yet."

guard-cranelift-compiler-mir-ingestion-corpus-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking compiler-owned MIR ingestion corpus surface..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    valid_return="compiler/fixtures/native_backend_return_int_ingestion.mir"
    valid_local="compiler/fixtures/native_backend_local_binding_read_ingestion.mir"
    valid_branch="compiler/fixtures/native_backend_conditional_branch_ingestion.mir"
    valid_add="compiler/fixtures/native_backend_add_i32_ingestion.mir"
    valid_provenance="compiler/fixtures/native_backend_provenance_metadata_ingestion.mir"
    valid_resource="compiler/fixtures/native_backend_resource_metadata_ingestion.mir"
    valid_native_boundary="compiler/fixtures/native_backend_native_boundary_metadata_ingestion.mir"
    valid_positive_branch="compiler/fixtures/native_backend_positive_i32_branch_ingestion.mir"
    valid_block_jump="compiler/fixtures/native_backend_block_jump_ingestion.mir"
    valid_block_local_branch="compiler/fixtures/native_backend_block_local_branch_ingestion.mir"
    valid_block_local_update_branch="compiler/fixtures/native_backend_block_local_update_branch_ingestion.mir"
    valid_block_two_local_update_branch="compiler/fixtures/native_backend_block_two_local_update_branch_ingestion.mir"
    valid_block_local_branch_join="compiler/fixtures/native_backend_block_local_branch_join_ingestion.mir"
    valid_block_param_update_branch="compiler/fixtures/native_backend_block_param_update_branch_ingestion.mir"
    valid_block_param_local_call_branch="compiler/fixtures/native_backend_block_param_local_call_branch_ingestion.mir"
    valid_block_param_imported_call_branch="compiler/fixtures/native_backend_block_param_imported_call_branch_ingestion.mir"
    valid_block_param_imported_call_return="compiler/fixtures/native_backend_block_param_imported_call_return_ingestion.mir"
    valid_block_param_imported_predicate_update_branch="compiler/fixtures/native_backend_block_param_imported_predicate_update_branch_ingestion.mir"
    valid_block_param_merge_update_branch="compiler/fixtures/native_backend_block_param_merge_update_branch_ingestion.mir"
    valid_block_param_merge_imported_call_return="compiler/fixtures/native_backend_block_param_merge_imported_call_return_ingestion.mir"
    valid_block_param_merge_arm_update_imported_call_return="compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_return_ingestion.mir"
    valid_block_param_merge_arm_update_imported_call_branch="compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_branch_ingestion.mir"
    valid_block_param_merge_imported_branch_joined_return="compiler/fixtures/native_backend_block_param_merge_imported_branch_joined_return_ingestion.mir"
    valid_block_param_merge_dual_imported_joined_return="compiler/fixtures/native_backend_block_param_merge_dual_imported_joined_return_ingestion.mir"
    valid_block_param_imported_materialize_branch="compiler/fixtures/native_backend_block_param_imported_materialize_branch_ingestion.mir"
    valid_block_param_local_materialize_branch="compiler/fixtures/native_backend_block_param_local_materialize_branch_ingestion.mir"
    valid_block_param_imported_materialize_return="compiler/fixtures/native_backend_block_param_imported_materialize_return_ingestion.mir"
    valid_block_param_local_materialize_return="compiler/fixtures/native_backend_block_param_local_materialize_return_ingestion.mir"
    valid_block_param_dual_materialize_return="compiler/fixtures/native_backend_block_param_dual_materialize_return_ingestion.mir"
    valid_block_param_local_first_dual_materialize_return="compiler/fixtures/native_backend_block_param_local_first_dual_materialize_return_ingestion.mir"
    valid_block_param_triple_materialize_return="compiler/fixtures/native_backend_block_param_triple_materialize_return_ingestion.mir"
    valid_block_param_quad_materialize_return="compiler/fixtures/native_backend_block_param_quad_materialize_return_ingestion.mir"
    valid_block_param_quint_materialize_return="compiler/fixtures/native_backend_block_param_quint_materialize_return_ingestion.mir"
    invalid_return="compiler/fixtures/native_backend_return_int_ingestion_invalid.mir"
    invalid_local="compiler/fixtures/native_backend_local_binding_read_ingestion_invalid.mir"
    invalid_branch="compiler/fixtures/native_backend_conditional_branch_ingestion_invalid.mir"
    invalid_add="compiler/fixtures/native_backend_add_i32_ingestion_invalid.mir"
    invalid_provenance="compiler/fixtures/native_backend_provenance_metadata_ingestion_invalid.mir"
    invalid_resource="compiler/fixtures/native_backend_resource_metadata_ingestion_invalid.mir"
    invalid_native_boundary="compiler/fixtures/native_backend_native_boundary_metadata_ingestion_invalid.mir"
    invalid_positive_branch="compiler/fixtures/native_backend_positive_i32_branch_ingestion_invalid.mir"
    invalid_block_jump="compiler/fixtures/native_backend_block_jump_ingestion_invalid.mir"
    invalid_block_local_branch="compiler/fixtures/native_backend_block_local_branch_ingestion_invalid.mir"
    invalid_block_local_update_branch="compiler/fixtures/native_backend_block_local_update_branch_ingestion_invalid.mir"
    invalid_block_two_local_update_branch="compiler/fixtures/native_backend_block_two_local_update_branch_ingestion_invalid.mir"
    invalid_block_local_branch_join="compiler/fixtures/native_backend_block_local_branch_join_ingestion_invalid.mir"
    invalid_block_param_update_branch="compiler/fixtures/native_backend_block_param_update_branch_ingestion_invalid.mir"
    invalid_block_param_local_call_branch="compiler/fixtures/native_backend_block_param_local_call_branch_ingestion_invalid.mir"
    invalid_block_param_imported_call_branch="compiler/fixtures/native_backend_block_param_imported_call_branch_ingestion_invalid.mir"
    invalid_block_param_imported_call_return="compiler/fixtures/native_backend_block_param_imported_call_return_ingestion_invalid.mir"
    invalid_block_param_imported_predicate_update_branch="compiler/fixtures/native_backend_block_param_imported_predicate_update_branch_ingestion_invalid.mir"
    invalid_block_param_merge_update_branch="compiler/fixtures/native_backend_block_param_merge_update_branch_ingestion_invalid.mir"
    invalid_block_param_merge_imported_call_return="compiler/fixtures/native_backend_block_param_merge_imported_call_return_ingestion_invalid.mir"
    invalid_block_param_merge_arm_update_imported_call_return="compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_return_ingestion_invalid.mir"
    invalid_block_param_merge_arm_update_imported_call_branch="compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_branch_ingestion_invalid.mir"
    invalid_block_param_merge_imported_branch_joined_return="compiler/fixtures/native_backend_block_param_merge_imported_branch_joined_return_ingestion_invalid.mir"
    invalid_block_param_merge_dual_imported_joined_return="compiler/fixtures/native_backend_block_param_merge_dual_imported_joined_return_ingestion_invalid.mir"
    invalid_block_param_imported_materialize_branch="compiler/fixtures/native_backend_block_param_imported_materialize_branch_ingestion_invalid.mir"
    invalid_block_param_local_materialize_branch="compiler/fixtures/native_backend_block_param_local_materialize_branch_ingestion_invalid.mir"
    invalid_block_param_imported_materialize_return="compiler/fixtures/native_backend_block_param_imported_materialize_return_ingestion_invalid.mir"
    invalid_block_param_local_materialize_return="compiler/fixtures/native_backend_block_param_local_materialize_return_ingestion_invalid.mir"
    invalid_block_param_dual_materialize_return="compiler/fixtures/native_backend_block_param_dual_materialize_return_ingestion_invalid.mir"
    invalid_block_param_local_first_dual_materialize_return="compiler/fixtures/native_backend_block_param_local_first_dual_materialize_return_ingestion_invalid.mir"
    invalid_block_param_triple_materialize_return="compiler/fixtures/native_backend_block_param_triple_materialize_return_ingestion_invalid.mir"
    invalid_block_param_quad_materialize_return="compiler/fixtures/native_backend_block_param_quad_materialize_return_ingestion_invalid.mir"
    invalid_block_param_quint_materialize_return="compiler/fixtures/native_backend_block_param_quint_materialize_return_ingestion_invalid.mir"

    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_INGESTION_CORPUS_SURFACE_GUARD: guard-cranelift-compiler-mir-ingestion-corpus-surface' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_corpus_surface_guard: guard-cranelift-compiler-mir-ingestion-corpus-surface' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_corpus_valid_fixture_count: 33' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_corpus_invalid_fixture_count: 33' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_corpus_valid_fixtures: compiler/fixtures/native_backend_return_int_ingestion.mir, compiler/fixtures/native_backend_local_binding_read_ingestion.mir, compiler/fixtures/native_backend_conditional_branch_ingestion.mir, compiler/fixtures/native_backend_add_i32_ingestion.mir, compiler/fixtures/native_backend_provenance_metadata_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_jump_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_local_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_local_update_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_two_local_update_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_local_branch_join_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_update_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_local_call_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_imported_call_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_imported_call_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_imported_predicate_update_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_merge_update_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_merge_imported_call_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_merge_imported_branch_joined_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_merge_dual_imported_joined_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_imported_materialize_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_local_materialize_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_imported_materialize_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_local_materialize_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_dual_materialize_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_local_first_dual_materialize_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_triple_materialize_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_quad_materialize_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_quint_materialize_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_corpus_invalid_fixtures: compiler/fixtures/native_backend_return_int_ingestion_invalid.mir, compiler/fixtures/native_backend_local_binding_read_ingestion_invalid.mir, compiler/fixtures/native_backend_conditional_branch_ingestion_invalid.mir, compiler/fixtures/native_backend_add_i32_ingestion_invalid.mir, compiler/fixtures/native_backend_provenance_metadata_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_jump_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_local_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_local_update_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_two_local_update_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_local_branch_join_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_update_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_local_call_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_imported_call_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_imported_call_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_imported_predicate_update_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_merge_update_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_merge_imported_call_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_merge_imported_branch_joined_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_merge_dual_imported_joined_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_imported_materialize_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_local_materialize_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_imported_materialize_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_local_materialize_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_dual_materialize_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_local_first_dual_materialize_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_triple_materialize_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_quad_materialize_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'compiler/fixtures/native_backend_block_param_quint_materialize_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_corpus_status: positive_and_negative_compiler_owned_fixture_inventory' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_corpus_suite_wiring: manifest_derived_native_guard_inventory' "$manifest_doc" >/dev/null

    for fixture in "$valid_return" "$valid_local" "$valid_branch" "$valid_add" "$valid_provenance" "$valid_resource" "$valid_native_boundary" "$valid_positive_branch" "$valid_block_jump" "$valid_block_local_branch" "$valid_block_local_update_branch" "$valid_block_two_local_update_branch" "$valid_block_local_branch_join" "$valid_block_param_update_branch" "$valid_block_param_local_call_branch" "$valid_block_param_imported_call_branch" "$valid_block_param_imported_call_return" "$valid_block_param_imported_predicate_update_branch" "$valid_block_param_merge_update_branch" "$valid_block_param_merge_imported_call_return" "$valid_block_param_merge_arm_update_imported_call_return" "$valid_block_param_merge_arm_update_imported_call_branch" "$valid_block_param_merge_imported_branch_joined_return" "$invalid_return" "$invalid_local" "$invalid_branch" "$invalid_add" "$invalid_provenance" "$invalid_resource" "$invalid_native_boundary" "$invalid_positive_branch" "$invalid_block_jump" "$invalid_block_local_branch" "$invalid_block_local_update_branch" "$invalid_block_two_local_update_branch" "$invalid_block_local_branch_join" "$invalid_block_param_update_branch" "$invalid_block_param_local_call_branch" "$invalid_block_param_imported_call_branch" "$invalid_block_param_imported_call_return" "$invalid_block_param_imported_predicate_update_branch" "$invalid_block_param_merge_update_branch" "$invalid_block_param_merge_imported_call_return" "$invalid_block_param_merge_arm_update_imported_call_return" "$invalid_block_param_merge_arm_update_imported_call_branch" "$invalid_block_param_merge_imported_branch_joined_return"; do
      if [ ! -f "$fixture" ]; then
        echo "Missing compiler-owned MIR ingestion corpus fixture: $fixture"
        exit 1
      fi
    done

    rg -n -F 'format: gust.compiler_mir_ingestion.return_int.v1' "$valid_return" "$invalid_return" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.local_binding_read.v1' "$valid_local" "$invalid_local" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.conditional_branch.v1' "$valid_branch" "$invalid_branch" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.add_i32.v1' "$valid_add" "$invalid_add" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.provenance_metadata.v1' "$valid_provenance" "$invalid_provenance" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.resource_metadata.v1' "$valid_resource" "$invalid_resource" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.native_boundary_metadata.v1' "$valid_native_boundary" "$invalid_native_boundary" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.positive_i32_branch.v1' "$valid_positive_branch" "$invalid_positive_branch" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_jump.v1' "$valid_block_jump" "$invalid_block_jump" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_local_branch.v1' "$valid_block_local_branch" "$invalid_block_local_branch" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_local_update_branch.v1' "$valid_block_local_update_branch" "$invalid_block_local_update_branch" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_two_local_update_branch.v1' "$valid_block_two_local_update_branch" "$invalid_block_two_local_update_branch" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_local_branch_join.v1' "$valid_block_local_branch_join" "$invalid_block_local_branch_join" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_update_branch.v1' "$valid_block_param_update_branch" "$invalid_block_param_update_branch" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_local_call_branch.v1' "$valid_block_param_local_call_branch" "$invalid_block_param_local_call_branch" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_imported_call_branch.v1' "$valid_block_param_imported_call_branch" "$invalid_block_param_imported_call_branch" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_imported_call_return.v1' "$valid_block_param_imported_call_return" "$invalid_block_param_imported_call_return" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_imported_predicate_update_branch.v1' "$valid_block_param_imported_predicate_update_branch" "$invalid_block_param_imported_predicate_update_branch" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_update_branch.v1' "$valid_block_param_merge_update_branch" "$invalid_block_param_merge_update_branch" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_imported_call_return.v1' "$valid_block_param_merge_imported_call_return" "$invalid_block_param_merge_imported_call_return" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_arm_update_imported_call_return.v1' "$valid_block_param_merge_arm_update_imported_call_return" "$invalid_block_param_merge_arm_update_imported_call_return" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_arm_update_imported_call_branch.v1' "$valid_block_param_merge_arm_update_imported_call_branch" "$invalid_block_param_merge_arm_update_imported_call_branch" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_imported_branch_joined_return.v1' "$valid_block_param_merge_imported_branch_joined_return" "$invalid_block_param_merge_imported_branch_joined_return" >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$valid_return" "$valid_local" "$valid_branch" "$valid_add" "$invalid_return" "$invalid_local" "$invalid_branch" "$invalid_add" >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$valid_block_jump" "$invalid_block_jump" >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$valid_block_local_branch" "$invalid_block_local_branch" >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$valid_block_local_update_branch" "$invalid_block_local_update_branch" >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$valid_block_two_local_update_branch" "$invalid_block_two_local_update_branch" >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$valid_block_local_branch_join" "$invalid_block_local_branch_join" >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$valid_block_param_update_branch" "$invalid_block_param_update_branch" >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$valid_block_param_local_call_branch" "$invalid_block_param_local_call_branch" >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$valid_block_param_imported_call_branch" "$invalid_block_param_imported_call_branch" >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$valid_block_param_imported_call_return" "$invalid_block_param_imported_call_return" >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$valid_block_param_imported_predicate_update_branch" "$invalid_block_param_imported_predicate_update_branch" >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$valid_block_param_merge_update_branch" "$invalid_block_param_merge_update_branch" >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$valid_block_param_merge_imported_call_return" "$invalid_block_param_merge_imported_call_return" >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$valid_block_param_merge_arm_update_imported_call_return" "$invalid_block_param_merge_arm_update_imported_call_return" >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$valid_block_param_merge_arm_update_imported_call_branch" "$invalid_block_param_merge_arm_update_imported_call_branch" >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$valid_block_param_merge_imported_branch_joined_return" "$invalid_block_param_merge_imported_branch_joined_return" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_return_int' "$valid_return" "$invalid_return" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_local_binding_read' "$valid_local" "$invalid_local" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_conditional_branch' "$valid_branch" "$invalid_branch" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_add_i32' "$valid_add" "$invalid_add" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_provenance_metadata' "$valid_provenance" "$invalid_provenance" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_resource_metadata' "$valid_resource" "$invalid_resource" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_native_boundary_metadata' "$valid_native_boundary" "$invalid_native_boundary" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_positive_i32_branch' "$valid_positive_branch" "$invalid_positive_branch" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_jump' "$valid_block_jump" "$invalid_block_jump" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_local_branch' "$valid_block_local_branch" "$invalid_block_local_branch" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_local_update_branch' "$valid_block_local_update_branch" "$invalid_block_local_update_branch" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_two_local_update_branch' "$valid_block_two_local_update_branch" "$invalid_block_two_local_update_branch" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_local_branch_join' "$valid_block_local_branch_join" "$invalid_block_local_branch_join" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_update_branch' "$valid_block_param_update_branch" "$invalid_block_param_update_branch" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_call_branch' "$valid_block_param_local_call_branch" "$invalid_block_param_local_call_branch" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_call_branch' "$valid_block_param_imported_call_branch" "$invalid_block_param_imported_call_branch" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return' "$valid_block_param_imported_call_return" "$invalid_block_param_imported_call_return" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_update_branch' "$valid_block_param_imported_predicate_update_branch" "$invalid_block_param_imported_predicate_update_branch" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_update_branch' "$valid_block_param_merge_update_branch" "$invalid_block_param_merge_update_branch" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return' "$valid_block_param_merge_imported_call_return" "$invalid_block_param_merge_imported_call_return" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return' "$valid_block_param_merge_arm_update_imported_call_return" "$invalid_block_param_merge_arm_update_imported_call_return" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch' "$valid_block_param_merge_arm_update_imported_call_branch" "$invalid_block_param_merge_arm_update_imported_call_branch" >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return' "$valid_block_param_merge_imported_branch_joined_return" "$invalid_block_param_merge_imported_branch_joined_return" >/dev/null

    rg -n -F 'return_value: 1' "$valid_return" >/dev/null
    rg -n -F 'return_value: 9' "$invalid_return" >/dev/null
    rg -n -F 'statement_0_value: 2' "$valid_local" >/dev/null
    rg -n -F 'statement_0_value: 9' "$invalid_local" >/dev/null
    rg -n -F 'branch_condition_value: 1' "$valid_branch" >/dev/null
    rg -n -F 'branch_condition_value: 0' "$invalid_branch" >/dev/null
    rg -n -F 'expected_case_0_result: 5' "$valid_add" >/dev/null
    rg -n -F 'provenance_metadata_count: 1' "$valid_provenance" "$invalid_provenance" >/dev/null
    rg -n -F 'provenance_0_kind: LocalBinding' "$valid_provenance" >/dev/null
    rg -n -F 'provenance_0_kind: NativeBoundary' "$invalid_provenance" >/dev/null
    rg -n -F 'resource_metadata_count: 1' "$valid_resource" "$invalid_resource" >/dev/null
    rg -n -F 'resource_0_state: Live' "$valid_resource" >/dev/null
    rg -n -F 'resource_0_state: Moved' "$invalid_resource" >/dev/null
    rg -n -F 'native_boundary_metadata_count: 1' "$valid_native_boundary" "$invalid_native_boundary" >/dev/null
    rg -n -F 'native_boundary_0_kind: RuntimeCall' "$valid_native_boundary" >/dev/null
    rg -n -F 'native_boundary_0_kind: LayoutSensitiveCall' "$invalid_native_boundary" >/dev/null
    rg -n -F 'branch_condition: greater_than_zero' "$valid_positive_branch" "$invalid_positive_branch" >/dev/null
    rg -n -F 'block_1_return_value: 7' "$valid_positive_branch" >/dev/null
    rg -n -F 'block_1_return_value: 8' "$invalid_positive_branch" >/dev/null
    rg -n -F 'block_2_return_value: 9' "$valid_positive_branch" "$invalid_positive_branch" >/dev/null
    rg -n -F 'block_0_terminator: Jump' "$valid_block_jump" "$invalid_block_jump" >/dev/null
    rg -n -F 'block_1_return_value: 1' "$valid_block_jump" >/dev/null
    rg -n -F 'block_1_return_value: 2' "$invalid_block_jump" >/dev/null
    rg -n -F 'block_0_statement_0_kind: LocalI32SetParam' "$valid_block_local_branch" "$invalid_block_local_branch" >/dev/null
    rg -n -F 'block_0_terminator: BranchLocalPositive' "$valid_block_local_branch" "$invalid_block_local_branch" >/dev/null
    rg -n -F 'block_1_return_value: 43' "$valid_block_local_branch" >/dev/null
    rg -n -F 'block_1_return_value: 44' "$invalid_block_local_branch" >/dev/null
    rg -n -F 'block_2_return_value: 47' "$valid_block_local_branch" "$invalid_block_local_branch" >/dev/null
    rg -n -F 'block_1_statement_0_kind: LocalI32AddI32Literal' "$valid_block_local_update_branch" "$invalid_block_local_update_branch" >/dev/null
    rg -n -F 'block_1_statement_0_value: 2' "$valid_block_local_update_branch" "$invalid_block_local_update_branch" >/dev/null
    rg -n -F 'block_2_return_value: 53' "$valid_block_local_update_branch" >/dev/null
    rg -n -F 'block_2_return_value: 54' "$invalid_block_local_update_branch" >/dev/null
    rg -n -F 'block_3_return_value: 59' "$valid_block_local_update_branch" "$invalid_block_local_update_branch" >/dev/null
    rg -n -F 'local_count: 2' "$valid_block_two_local_update_branch" "$invalid_block_two_local_update_branch" >/dev/null
    rg -n -F 'block_0_statement_0_local: raw' "$valid_block_two_local_update_branch" "$invalid_block_two_local_update_branch" >/dev/null
    rg -n -F 'block_0_statement_1_local: adjusted' "$valid_block_two_local_update_branch" "$invalid_block_two_local_update_branch" >/dev/null
    rg -n -F 'block_1_statement_0_kind: LocalI32AddI32Literal' "$valid_block_two_local_update_branch" "$invalid_block_two_local_update_branch" >/dev/null
    rg -n -F 'block_1_statement_0_value: 3' "$valid_block_two_local_update_branch" "$invalid_block_two_local_update_branch" >/dev/null
    rg -n -F 'block_1_branch_local: adjusted' "$valid_block_two_local_update_branch" "$invalid_block_two_local_update_branch" >/dev/null
    rg -n -F 'block_2_return_value: 61' "$valid_block_two_local_update_branch" >/dev/null
    rg -n -F 'block_2_return_value: 62' "$invalid_block_two_local_update_branch" >/dev/null
    rg -n -F 'block_3_return_value: 67' "$valid_block_two_local_update_branch" "$invalid_block_two_local_update_branch" >/dev/null
    rg -n -F 'block_0_terminator: BranchLocalPositive' "$valid_block_local_branch_join" "$invalid_block_local_branch_join" >/dev/null
    rg -n -F 'block_1_statement_0_value: 4' "$valid_block_local_branch_join" >/dev/null
    rg -n -F 'block_1_statement_0_value: 5' "$invalid_block_local_branch_join" >/dev/null
    rg -n -F 'block_1_target: join' "$valid_block_local_branch_join" "$invalid_block_local_branch_join" >/dev/null
    rg -n -F 'block_2_statement_0_value: 8' "$valid_block_local_branch_join" "$invalid_block_local_branch_join" >/dev/null
    rg -n -F 'block_2_target: join' "$valid_block_local_branch_join" "$invalid_block_local_branch_join" >/dev/null
    rg -n -F 'block_3_return_value_kind: LocalRead' "$valid_block_local_branch_join" "$invalid_block_local_branch_join" >/dev/null
    rg -n -F 'block_3_return_local: value' "$valid_block_local_branch_join" "$invalid_block_local_branch_join" >/dev/null
    rg -n -F 'block_0_terminator: JumpFunctionParam' "$valid_block_param_update_branch" "$invalid_block_param_update_branch" >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamAddI32Literal' "$valid_block_param_update_branch" "$invalid_block_param_update_branch" >/dev/null
    rg -n -F 'block_1_add_value: 4' "$valid_block_param_update_branch" "$invalid_block_param_update_branch" >/dev/null
    rg -n -F 'block_2_terminator: BranchBlockParamPositive' "$valid_block_param_update_branch" "$invalid_block_param_update_branch" >/dev/null
    rg -n -F 'block_3_return_value: 67' "$valid_block_param_update_branch" >/dev/null
    rg -n -F 'block_3_return_value: 68' "$invalid_block_param_update_branch" >/dev/null
    rg -n -F 'block_4_return_value: 71' "$valid_block_param_update_branch" "$invalid_block_param_update_branch" >/dev/null
    rg -n -F 'local_function_0_operation: AddI32Literal' "$valid_block_param_local_call_branch" "$invalid_block_param_local_call_branch" >/dev/null
    rg -n -F 'local_function_0_add_value: 1' "$valid_block_param_local_call_branch" "$invalid_block_param_local_call_branch" >/dev/null
    rg -n -F 'block_1_terminator: BranchBlockParamLocalFunctionPositive' "$valid_block_param_local_call_branch" "$invalid_block_param_local_call_branch" >/dev/null
    rg -n -F 'block_2_return_value: 79' "$valid_block_param_local_call_branch" >/dev/null
    rg -n -F 'block_2_return_value: 80' "$invalid_block_param_local_call_branch" >/dev/null
    rg -n -F 'block_3_return_value: 83' "$valid_block_param_local_call_branch" "$invalid_block_param_local_call_branch" >/dev/null
    rg -n -F 'imported_function_0_operation: HostAddI32' "$valid_block_param_imported_call_branch" "$invalid_block_param_imported_call_branch" >/dev/null
    rg -n -F 'block_1_terminator: BranchBlockParamImportedFunctionCallI32LiteralPositive' "$valid_block_param_imported_call_branch" "$invalid_block_param_imported_call_branch" >/dev/null
    rg -n -F 'block_1_call_literal: -3' "$valid_block_param_imported_call_branch" "$invalid_block_param_imported_call_branch" >/dev/null
    rg -n -F 'block_2_return_value: 89' "$valid_block_param_imported_call_branch" >/dev/null
    rg -n -F 'block_2_return_value: 90' "$invalid_block_param_imported_call_branch" >/dev/null
    rg -n -F 'block_3_return_value: 97' "$valid_block_param_imported_call_branch" "$invalid_block_param_imported_call_branch" >/dev/null
    rg -n -F 'block_1_terminator: ReturnBlockParamImportedFunctionCallI32Literal' "$valid_block_param_imported_call_return" "$invalid_block_param_imported_call_return" >/dev/null
    rg -n -F 'block_1_call_literal: 11' "$valid_block_param_imported_call_return" >/dev/null
    rg -n -F 'block_1_call_literal: 12' "$invalid_block_param_imported_call_return" >/dev/null
    rg -n -F 'expected_case_0_result: 16' "$valid_block_param_imported_call_return" "$invalid_block_param_imported_call_return" >/dev/null
    rg -n -F 'expected_case_1_result: 11' "$valid_block_param_imported_call_return" "$invalid_block_param_imported_call_return" >/dev/null
    rg -n -F 'expected_case_2_result: -1' "$valid_block_param_imported_call_return" "$invalid_block_param_imported_call_return" >/dev/null
    rg -n -F 'imported_function_0_operation: HostIsPositiveI32' "$valid_block_param_imported_predicate_update_branch" "$invalid_block_param_imported_predicate_update_branch" >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamAddI32Literal' "$valid_block_param_imported_predicate_update_branch" "$invalid_block_param_imported_predicate_update_branch" >/dev/null
    rg -n -F 'block_1_add_value: -4' "$valid_block_param_imported_predicate_update_branch" "$invalid_block_param_imported_predicate_update_branch" >/dev/null
    rg -n -F 'block_2_terminator: BranchBlockParamImportedFunctionPredicate' "$valid_block_param_imported_predicate_update_branch" "$invalid_block_param_imported_predicate_update_branch" >/dev/null
    rg -n -F 'block_3_return_value: 101' "$valid_block_param_imported_predicate_update_branch" >/dev/null
    rg -n -F 'block_3_return_value: 102' "$invalid_block_param_imported_predicate_update_branch" >/dev/null
    rg -n -F 'block_4_return_value: 107' "$valid_block_param_imported_predicate_update_branch" "$invalid_block_param_imported_predicate_update_branch" >/dev/null
    rg -n -F 'block_2_terminator: BranchBlockParamPositiveToI32Literals' "$valid_block_param_merge_update_branch" "$invalid_block_param_merge_update_branch" >/dev/null
    rg -n -F 'branch_then_value: 181' "$valid_block_param_merge_update_branch" >/dev/null
    rg -n -F 'branch_then_value: 182' "$invalid_block_param_merge_update_branch" >/dev/null
    rg -n -F 'branch_else_value: 191' "$valid_block_param_merge_update_branch" "$invalid_block_param_merge_update_branch" >/dev/null
    rg -n -F 'block_3_target: join' "$valid_block_param_merge_update_branch" "$invalid_block_param_merge_update_branch" >/dev/null
    rg -n -F 'block_4_target: join' "$valid_block_param_merge_update_branch" "$invalid_block_param_merge_update_branch" >/dev/null
    rg -n -F 'block_5_terminator: ReturnBlockParam' "$valid_block_param_merge_update_branch" "$invalid_block_param_merge_update_branch" >/dev/null
    rg -n -F 'expected_case_0_result: 181' "$valid_block_param_merge_update_branch" "$invalid_block_param_merge_update_branch" >/dev/null
    rg -n -F 'expected_case_1_result: 191' "$valid_block_param_merge_update_branch" "$invalid_block_param_merge_update_branch" >/dev/null
    rg -n -F 'block_2_terminator: BranchBlockParamPositiveToI32Literals' "$valid_block_param_merge_imported_call_return" "$invalid_block_param_merge_imported_call_return" >/dev/null
    rg -n -F 'branch_then_value: 211' "$valid_block_param_merge_imported_call_return" >/dev/null
    rg -n -F 'branch_then_value: 212' "$invalid_block_param_merge_imported_call_return" >/dev/null
    rg -n -F 'branch_else_value: 223' "$valid_block_param_merge_imported_call_return" "$invalid_block_param_merge_imported_call_return" >/dev/null
    rg -n -F 'block_5_terminator: ReturnBlockParamImportedFunctionCallI32Literal' "$valid_block_param_merge_imported_call_return" "$invalid_block_param_merge_imported_call_return" >/dev/null
    rg -n -F 'block_5_call_literal: 5' "$valid_block_param_merge_imported_call_return" "$invalid_block_param_merge_imported_call_return" >/dev/null
    rg -n -F 'expected_case_0_result: 216' "$valid_block_param_merge_imported_call_return" "$invalid_block_param_merge_imported_call_return" >/dev/null
    rg -n -F 'expected_case_1_result: 228' "$valid_block_param_merge_imported_call_return" "$invalid_block_param_merge_imported_call_return" >/dev/null
    rg -n -F 'block_3_add_value: 7' "$valid_block_param_merge_arm_update_imported_call_return" >/dev/null
    rg -n -F 'block_3_add_value: 8' "$invalid_block_param_merge_arm_update_imported_call_return" >/dev/null
    rg -n -F 'block_4_add_value: 9' "$valid_block_param_merge_arm_update_imported_call_return" "$invalid_block_param_merge_arm_update_imported_call_return" >/dev/null
    rg -n -F 'block_5_terminator: ReturnBlockParamImportedFunctionCallI32Literal' "$valid_block_param_merge_arm_update_imported_call_return" "$invalid_block_param_merge_arm_update_imported_call_return" >/dev/null
    rg -n -F 'block_5_call_literal: 5' "$valid_block_param_merge_arm_update_imported_call_return" "$invalid_block_param_merge_arm_update_imported_call_return" >/dev/null
    rg -n -F 'expected_case_0_result: 223' "$valid_block_param_merge_arm_update_imported_call_return" "$invalid_block_param_merge_arm_update_imported_call_return" >/dev/null
    rg -n -F 'expected_case_1_result: 237' "$valid_block_param_merge_arm_update_imported_call_return" "$invalid_block_param_merge_arm_update_imported_call_return" >/dev/null
    rg -n -F 'block_5_terminator: BranchBlockParamImportedFunctionCallI32LiteralPositive' "$valid_block_param_merge_arm_update_imported_call_branch" "$invalid_block_param_merge_arm_update_imported_call_branch" >/dev/null
    rg -n -F 'block_5_call_literal: -220' "$valid_block_param_merge_arm_update_imported_call_branch" "$invalid_block_param_merge_arm_update_imported_call_branch" >/dev/null
    rg -n -F 'block_6_return_value: 241' "$valid_block_param_merge_arm_update_imported_call_branch" "$invalid_block_param_merge_arm_update_imported_call_branch" >/dev/null
    rg -n -F 'block_7_return_value: 251' "$valid_block_param_merge_arm_update_imported_call_branch" "$invalid_block_param_merge_arm_update_imported_call_branch" >/dev/null
    rg -n -F 'block_3_add_value: 7' "$valid_block_param_merge_arm_update_imported_call_branch" >/dev/null
    rg -n -F 'block_3_add_value: 8' "$invalid_block_param_merge_arm_update_imported_call_branch" >/dev/null
    rg -n -F 'expected_case_0_result: 251' "$valid_block_param_merge_arm_update_imported_call_branch" "$invalid_block_param_merge_arm_update_imported_call_branch" >/dev/null
    rg -n -F 'expected_case_1_result: 241' "$valid_block_param_merge_arm_update_imported_call_branch" "$invalid_block_param_merge_arm_update_imported_call_branch" >/dev/null
    rg -n -F 'block_5_terminator: BranchBlockParamImportedFunctionCallI32LiteralPositive' "$valid_block_param_merge_imported_branch_joined_return" "$invalid_block_param_merge_imported_branch_joined_return" >/dev/null
    rg -n -F 'block_6_terminator: JumpI32Literal' "$valid_block_param_merge_imported_branch_joined_return" "$invalid_block_param_merge_imported_branch_joined_return" >/dev/null
    rg -n -F 'block_7_terminator: JumpI32Literal' "$valid_block_param_merge_imported_branch_joined_return" "$invalid_block_param_merge_imported_branch_joined_return" >/dev/null
    rg -n -F 'block_8_terminator: ReturnBlockParamImportedFunctionCallI32Literal' "$valid_block_param_merge_imported_branch_joined_return" "$invalid_block_param_merge_imported_branch_joined_return" >/dev/null
    rg -n -F 'block_8_call_literal: 3' "$valid_block_param_merge_imported_branch_joined_return" "$invalid_block_param_merge_imported_branch_joined_return" >/dev/null
    rg -n -F 'expected_case_0_result: 254' "$valid_block_param_merge_imported_branch_joined_return" "$invalid_block_param_merge_imported_branch_joined_return" >/dev/null
    rg -n -F 'expected_case_1_result: 244' "$valid_block_param_merge_imported_branch_joined_return" "$invalid_block_param_merge_imported_branch_joined_return" >/dev/null
    rg -n -F 'expected_case_0_result: 6' "$invalid_add" >/dev/null

    for guard_recipe in \
      guard-cranelift-compiler-mir-return-int-ingestion-native-smoke \
      guard-cranelift-compiler-mir-local-binding-read-ingestion-native-smoke \
      guard-cranelift-compiler-mir-conditional-branch-ingestion-native-smoke \
      guard-cranelift-compiler-mir-add-i32-ingestion-native-smoke \
      guard-cranelift-compiler-mir-provenance-metadata-ingestion-native-smoke \
      guard-cranelift-compiler-mir-resource-metadata-ingestion-native-smoke \
      guard-cranelift-compiler-mir-native-boundary-metadata-ingestion-native-smoke \
      guard-cranelift-compiler-mir-positive-i32-branch-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-jump-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-local-branch-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-local-update-branch-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-two-local-update-branch-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-local-branch-join-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-update-branch-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-local-call-branch-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-imported-call-branch-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-imported-call-return-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-imported-predicate-update-branch-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-merge-update-branch-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-merge-imported-call-return-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-merge-arm-update-imported-call-return-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-merge-arm-update-imported-call-branch-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-merge-imported-branch-joined-return-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-merge-dual-imported-joined-return-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-imported-materialize-branch-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-local-materialize-branch-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-imported-materialize-return-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-local-materialize-return-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-dual-materialize-return-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-local-first-dual-materialize-return-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-triple-materialize-return-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-quad-materialize-return-ingestion-native-smoke \
      guard-cranelift-compiler-mir-block-param-quint-materialize-return-ingestion-native-smoke \
      guard-cranelift-compiler-mir-ingestion-invalid-fixtures-native-rejection
    do
      rg -n -F "$guard_recipe" "$manifest_doc" justfile >/dev/null
    done

    suite_body="$(sed -n '/^guard-cranelift-experimental-backend-suite:/,/^guard-mir-feature-return-int-preservation:/p' justfile)"
    printf '%s\n' "$suite_body" | rg -n -F 'suite_native_guards="$(awk' >/dev/null
    printf '%s\n' "$suite_body" | rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_.*NATIVE_GUARD: guard-cranelift-' >/dev/null
    printf '%s\n' "$suite_body" | rg -n -F 'just "$guard_recipe"' >/dev/null

    fixture_cranelift_refs="$(rg -n -i -F 'cranelift' "$valid_return" "$valid_local" "$valid_branch" "$valid_add" "$valid_provenance" "$valid_resource" "$valid_native_boundary" "$valid_positive_branch" "$valid_block_jump" "$valid_block_local_branch" "$valid_block_local_update_branch" "$valid_block_two_local_update_branch" "$valid_block_local_branch_join" "$valid_block_param_update_branch" "$valid_block_param_local_call_branch" "$valid_block_param_imported_call_branch" "$valid_block_param_imported_call_return" "$valid_block_param_imported_predicate_update_branch" "$valid_block_param_merge_update_branch" "$valid_block_param_merge_imported_call_return" "$valid_block_param_merge_arm_update_imported_call_return" "$valid_block_param_merge_arm_update_imported_call_branch" "$valid_block_param_merge_imported_branch_joined_return" "$invalid_return" "$invalid_local" "$invalid_branch" "$invalid_add" "$invalid_provenance" "$invalid_resource" "$invalid_native_boundary" "$invalid_positive_branch" "$invalid_block_jump" "$invalid_block_local_branch" "$invalid_block_local_update_branch" "$invalid_block_two_local_update_branch" "$invalid_block_local_branch_join" "$invalid_block_param_update_branch" "$invalid_block_param_local_call_branch" "$invalid_block_param_imported_call_branch" "$invalid_block_param_imported_call_return" "$invalid_block_param_imported_predicate_update_branch" "$invalid_block_param_merge_update_branch" "$invalid_block_param_merge_imported_call_return" "$invalid_block_param_merge_arm_update_imported_call_return" "$invalid_block_param_merge_arm_update_imported_call_branch" "$invalid_block_param_merge_imported_branch_joined_return" || true)"
    if [ -n "$fixture_cranelift_refs" ]; then
      echo "Compiler-owned MIR ingestion fixtures must not mention Cranelift; backend coupling stays manifest/experiment-only:"
      echo "$fixture_cranelift_refs"
      exit 1
    fi

    echo "✅ Compiler-owned MIR ingestion corpus surface passed."

guard-cranelift-backend-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Cranelift backend surface..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-experiment-manifest-surface
    just guard-cranelift-experiment-guard-wiring-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_CODEGEN_STATUS: return_int_local_binding_branch_differential_fixture_only' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_BACKEND_SURFACE_STATUS: differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_PRIMARY_ROUTE: mir_to_c' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ENABLED_BY_DEFAULT: false' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_BACKEND_SURFACE_GUARD: guard-cranelift-backend-surface' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_GUARD_WIRING_SURFACE: guard-cranelift-experiment-guard-wiring-surface' "$manifest_doc" justfile >/dev/null
    codegen_entry_refs="$(rg -n '^allowed_.*_codegen_entry:' "$manifest_doc" || true)"
    unexpected_codegen_entries="$(printf '%s\n' "$codegen_entry_refs" | rg -v -F 'compiler/experiments/cranelift/src/main.rs' || true)"
    if [ -n "$unexpected_codegen_entries" ]; then
      echo "Cranelift experiment codegen entries must stay isolated under compiler/experiments/cranelift/src/main.rs:"
      echo "$unexpected_codegen_entries"
      exit 1
    fi
    object_artifact_refs="$(rg -n '^allowed_.*_object_artifact:' "$manifest_doc" || true)"
    unexpected_object_artifacts="$(printf '%s\n' "$object_artifact_refs" | rg -v -F 'build/guards/cranelift' || true)"
    if [ -n "$unexpected_object_artifacts" ]; then
      echo "Cranelift object artifacts must stay under build/guards/cranelift*:"
      echo "$unexpected_object_artifacts"
      exit 1
    fi
    backend_route_flag="$(printf '%s %s' '--backend' 'cranelift')"
    backend_route_refs="$(rg -n -F -- "$backend_route_flag" compiler src tests Makefile Cargo.toml Cargo.lock justfile 2>/dev/null | rg -v '^compiler/CRANELIFT_EXPERIMENT_MANIFEST\.md:' || true)"
    if [ -n "$backend_route_refs" ]; then
      echo "Production Cranelift backend routing must not exist yet."
      echo "$backend_route_refs"
      exit 1
    fi
    implementation_refs="$(rg -n -i 'cranelift_codegen|cranelift_emit|cranelift_compile|CraneliftBackend' compiler src tests Cargo.toml Cargo.lock Makefile 2>/dev/null | rg -v '^compiler/CRANELIFT_EXPERIMENT_MANIFEST\.md:' | rg -v '^compiler/experiments/cranelift/' || true)"
    if [ -n "$implementation_refs" ]; then
      echo "Cranelift backend surface must not include production codegen, root deps, or non-experiment implementation refs yet:"
      echo "$implementation_refs"
      exit 1
    fi
    echo "✅ Cranelift backend surface passed: guard inventory is manifest-derived, Cranelift remains isolated, and production codegen/routes are still absent."

guard-cranelift-return-int-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling real experimental Cranelift return-int smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_CODEGEN_STATUS: return_int_local_binding_branch_differential_fixture_only' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_RETURN_INT_NATIVE_GUARD: guard-cranelift-return-int-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_return_int_fixture: tiny_cranelift_return_int' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_return_int_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_return_int_object_artifact: build/guards/cranelift_return_int_native/tiny_cranelift_return_int.o' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_return_int_native
    object_file="build/guards/cranelift_return_int_native/tiny_cranelift_return_int.o"
    shim_c="build/guards/cranelift_return_int_native/tiny_cranelift_return_int_main.c"
    binary="build/guards/cranelift_return_int_native/tiny_cranelift_return_int_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- return-int-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected Cranelift return-int object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_return_int(void);' >> "$shim_c"
    printf '%s\n' 'int main(void) { return tiny_cranelift_return_int(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "1" ]; then
      echo "Expected real experimental Cranelift return-int native smoke to exit with status 1, got $status"
      exit 1
    fi
    echo "✅ Real experimental Cranelift return-int native smoke passed."

guard-cranelift-local-binding-read-native-smoke:
    just guard-cranelift-local-binding-native-smoke

guard-cranelift-local-binding-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling real experimental Cranelift local-binding smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_CODEGEN_STATUS: return_int_local_binding_branch_differential_fixture_only' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_LOCAL_BINDING_NATIVE_GUARD: guard-cranelift-local-binding-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_local_binding_fixture: tiny_cranelift_local_binding_read' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_local_binding_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_local_binding_object_artifact: build/guards/cranelift_local_binding_native/tiny_cranelift_local_binding_read.o' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_local_binding_native
    object_file="build/guards/cranelift_local_binding_native/tiny_cranelift_local_binding_read.o"
    shim_c="build/guards/cranelift_local_binding_native/tiny_cranelift_local_binding_read_main.c"
    binary="build/guards/cranelift_local_binding_native/tiny_cranelift_local_binding_read_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- local-binding-read-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected Cranelift local-binding object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_local_binding_read(void);' >> "$shim_c"
    printf '%s\n' 'int main(void) { return tiny_cranelift_local_binding_read(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "2" ]; then
      echo "Expected real experimental Cranelift local-binding native smoke to exit with status 2, got $status"
      exit 1
    fi
    echo "✅ Real experimental Cranelift local-binding native smoke passed."

guard-cranelift-branch-native-smoke:
    just guard-cranelift-conditional-branch-native-smoke

guard-cranelift-conditional-branch-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling real experimental Cranelift conditional-branch smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_CODEGEN_STATUS: return_int_local_binding_branch_object_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_BRANCH_NATIVE_GUARD: guard-cranelift-conditional-branch-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_branch_fixture: tiny_cranelift_conditional_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_branch_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_branch_object_artifact: build/guards/cranelift_conditional_branch_native/tiny_cranelift_conditional_branch.o' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_conditional_branch_native
    object_file="build/guards/cranelift_conditional_branch_native/tiny_cranelift_conditional_branch.o"
    shim_c="build/guards/cranelift_conditional_branch_native/tiny_cranelift_conditional_branch_main.c"
    binary="build/guards/cranelift_conditional_branch_native/tiny_cranelift_conditional_branch_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- conditional-branch-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected Cranelift conditional-branch object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_conditional_branch(void);' >> "$shim_c"
    printf '%s\n' 'int main(void) { return tiny_cranelift_conditional_branch(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "1" ]; then
      echo "Expected real experimental Cranelift conditional-branch native smoke to exit with status 1, got $status"
      exit 1
    fi
    echo "✅ Real experimental Cranelift conditional-branch native smoke passed."


guard-cranelift-identity-i32-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling real experimental Cranelift identity-i32 smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_IDENTITY_I32_NATIVE_GUARD: guard-cranelift-identity-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_identity_i32_native_guard: guard-cranelift-identity-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_identity_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_identity_i32_object_artifact: build/guards/cranelift_identity_i32_native/tiny_cranelift_identity_i32.o' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_identity_i32_native
    object_file="build/guards/cranelift_identity_i32_native/tiny_cranelift_identity_i32.o"
    shim_c="build/guards/cranelift_identity_i32_native/tiny_cranelift_identity_i32_main.c"
    binary="build/guards/cranelift_identity_i32_native/tiny_cranelift_identity_i32_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- identity-i32-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected Cranelift identity-i32 object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_identity_i32(int32_t value);' >> "$shim_c"
    printf '%s\n' 'int main(void) { return tiny_cranelift_identity_i32(3); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "3" ]; then
      echo "Expected real experimental Cranelift identity-i32 native smoke to exit with status 3, got $status"
      exit 1
    fi
    echo "✅ Real experimental Cranelift identity-i32 native smoke passed."


guard-cranelift-add-i32-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling real experimental Cranelift add-i32 smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_ADD_I32_NATIVE_GUARD: guard-cranelift-add-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_add_i32_native_guard: guard-cranelift-add-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_add_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_add_i32_object_artifact: build/guards/cranelift_add_i32_native/tiny_cranelift_add_i32.o' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_add_i32_native
    object_file="build/guards/cranelift_add_i32_native/tiny_cranelift_add_i32.o"
    shim_c="build/guards/cranelift_add_i32_native/tiny_cranelift_add_i32_main.c"
    binary="build/guards/cranelift_add_i32_native/tiny_cranelift_add_i32_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- add-i32-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected Cranelift add-i32 object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_add_i32(int32_t lhs, int32_t rhs);' >> "$shim_c"
    printf '%s\n' 'int main(void) { return tiny_cranelift_add_i32(2, 3); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "5" ]; then
      echo "Expected real experimental Cranelift add-i32 native smoke to exit with status 5, got $status"
      exit 1
    fi
    echo "✅ Real experimental Cranelift add-i32 native smoke passed."

guard-cranelift-positive-i32-branch-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling real experimental Cranelift positive-i32 branch smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_POSITIVE_I32_BRANCH_NATIVE_GUARD: guard-cranelift-positive-i32-branch-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_positive_i32_branch_native_guard: guard-cranelift-positive-i32-branch-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_positive_i32_branch_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_positive_i32_branch_object_artifact: build/guards/cranelift_positive_i32_branch_native/tiny_cranelift_positive_i32_branch.o' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_positive_i32_branch_native
    object_file="build/guards/cranelift_positive_i32_branch_native/tiny_cranelift_positive_i32_branch.o"
    shim_c="build/guards/cranelift_positive_i32_branch_native/tiny_cranelift_positive_i32_branch_main.c"
    binary="build/guards/cranelift_positive_i32_branch_native/tiny_cranelift_positive_i32_branch_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- positive-i32-branch-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected Cranelift positive-i32 branch object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_positive_i32_branch(int32_t value);' >> "$shim_c"
    printf '%s\n' 'int main(void) {' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_positive_i32_branch(1) != 7) {' >> "$shim_c"
    printf '%s\n' '    return 1;' >> "$shim_c"
    printf '%s\n' '  }' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_positive_i32_branch(0) != 9) {' >> "$shim_c"
    printf '%s\n' '    return 2;' >> "$shim_c"
    printf '%s\n' '  }' >> "$shim_c"
    printf '%s\n' '  return 5;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "5" ]; then
      echo "Expected real experimental Cranelift positive-i32 branch native smoke to exit with status 5, got $status"
      exit 1
    fi
    echo "✅ Real experimental Cranelift positive-i32 branch native smoke passed."

guard-cranelift-increment-local-i32-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling real experimental Cranelift increment-local-i32 smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_INCREMENT_LOCAL_I32_NATIVE_GUARD: guard-cranelift-increment-local-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_increment_local_i32_native_guard: guard-cranelift-increment-local-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_increment_local_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_increment_local_i32_object_artifact: build/guards/cranelift_increment_local_i32_native/tiny_cranelift_increment_local_i32.o' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_increment_local_i32_native
    object_file="build/guards/cranelift_increment_local_i32_native/tiny_cranelift_increment_local_i32.o"
    shim_c="build/guards/cranelift_increment_local_i32_native/tiny_cranelift_increment_local_i32_main.c"
    binary="build/guards/cranelift_increment_local_i32_native/tiny_cranelift_increment_local_i32_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- increment-local-i32-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected Cranelift increment-local-i32 object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_increment_local_i32(int32_t value);' >> "$shim_c"
    printf '%s\n' 'int main(void) {' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_increment_local_i32(4) != 5) {' >> "$shim_c"
    printf '%s\n' '    return 1;' >> "$shim_c"
    printf '%s\n' '  }' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_increment_local_i32(0) != 1) {' >> "$shim_c"
    printf '%s\n' '    return 2;' >> "$shim_c"
    printf '%s\n' '  }' >> "$shim_c"
    printf '%s\n' '  return 6;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "6" ]; then
      echo "Expected real experimental Cranelift increment-local-i32 native smoke to exit with status 6, got $status"
      exit 1
    fi
    echo "✅ Real experimental Cranelift increment-local-i32 native smoke passed."

guard-cranelift-call-helper-i32-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling real experimental Cranelift call-helper-i32 smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_CALL_HELPER_I32_NATIVE_GUARD: guard-cranelift-call-helper-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_call_helper_i32_native_guard: guard-cranelift-call-helper-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_call_helper_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_call_helper_i32_object_artifact: build/guards/cranelift_call_helper_i32_native/tiny_cranelift_call_helper_i32.o' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_call_helper_i32_native
    object_file="build/guards/cranelift_call_helper_i32_native/tiny_cranelift_call_helper_i32.o"
    shim_c="build/guards/cranelift_call_helper_i32_native/tiny_cranelift_call_helper_i32_main.c"
    binary="build/guards/cranelift_call_helper_i32_native/tiny_cranelift_call_helper_i32_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- call-helper-i32-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected Cranelift call-helper-i32 object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_call_helper_i32(int32_t value);' >> "$shim_c"
    printf '%s\n' 'int main(void) {' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_call_helper_i32(4) != 5) {' >> "$shim_c"
    printf '%s\n' '    return 1;' >> "$shim_c"
    printf '%s\n' '  }' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_call_helper_i32(0) != 1) {' >> "$shim_c"
    printf '%s\n' '    return 2;' >> "$shim_c"
    printf '%s\n' '  }' >> "$shim_c"
    printf '%s\n' '  return 7;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "7" ]; then
      echo "Expected real experimental Cranelift call-helper-i32 native smoke to exit with status 7, got $status"
      exit 1
    fi
    echo "✅ Real experimental Cranelift call-helper-i32 native smoke passed."

guard-cranelift-extern-call-i32-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling real experimental Cranelift extern-call-i32 smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_EXTERN_CALL_I32_NATIVE_GUARD: guard-cranelift-extern-call-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_extern_call_i32_native_guard: guard-cranelift-extern-call-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_call_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_call_i32_object_artifact: build/guards/cranelift_extern_call_i32_native/tiny_cranelift_extern_call_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_call_i32_host_symbol: tiny_host_add_one_i32' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_extern_call_i32_native
    object_file="build/guards/cranelift_extern_call_i32_native/tiny_cranelift_extern_call_i32.o"
    shim_c="build/guards/cranelift_extern_call_i32_native/tiny_cranelift_extern_call_i32_main.c"
    binary="build/guards/cranelift_extern_call_i32_native/tiny_cranelift_extern_call_i32_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- extern-call-i32-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected Cranelift extern-call-i32 object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'int32_t tiny_host_add_one_i32(int32_t value) {' >> "$shim_c"
    printf '%s\n' '  return value + 1;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_extern_call_i32(int32_t value);' >> "$shim_c"
    printf '%s\n' 'int main(void) {' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_extern_call_i32(4) != 5) {' >> "$shim_c"
    printf '%s\n' '    return 1;' >> "$shim_c"
    printf '%s\n' '  }' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_extern_call_i32(0) != 1) {' >> "$shim_c"
    printf '%s\n' '    return 2;' >> "$shim_c"
    printf '%s\n' '  }' >> "$shim_c"
    printf '%s\n' '  return 8;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "8" ]; then
      echo "Expected real experimental Cranelift extern-call-i32 native smoke to exit with status 8, got $status"
      exit 1
    fi
    echo "✅ Real experimental Cranelift extern-call-i32 native smoke passed."

guard-cranelift-extern-add-i32-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling real experimental Cranelift extern-add-i32 smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_EXTERN_ADD_I32_NATIVE_GUARD: guard-cranelift-extern-add-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_extern_add_i32_native_guard: guard-cranelift-extern-add-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_add_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_add_i32_object_artifact: build/guards/cranelift_extern_add_i32_native/tiny_cranelift_extern_add_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_add_i32_host_symbol: tiny_host_add_i32' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_extern_add_i32_native
    object_file="build/guards/cranelift_extern_add_i32_native/tiny_cranelift_extern_add_i32.o"
    shim_c="build/guards/cranelift_extern_add_i32_native/tiny_cranelift_extern_add_i32_main.c"
    binary="build/guards/cranelift_extern_add_i32_native/tiny_cranelift_extern_add_i32_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- extern-add-i32-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected Cranelift extern-add-i32 object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'int32_t tiny_host_add_i32(int32_t lhs, int32_t rhs) {' >> "$shim_c"
    printf '%s\n' '  return lhs + rhs;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_extern_add_i32(int32_t value);' >> "$shim_c"
    printf '%s\n' 'int main(void) {' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_extern_add_i32(4) != 7) {' >> "$shim_c"
    printf '%s\n' '    return 1;' >> "$shim_c"
    printf '%s\n' '  }' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_extern_add_i32(0) != 3) {' >> "$shim_c"
    printf '%s\n' '    return 2;' >> "$shim_c"
    printf '%s\n' '  }' >> "$shim_c"
    printf '%s\n' '  return 9;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "9" ]; then
      echo "Expected real experimental Cranelift extern-add-i32 native smoke to exit with status 9, got $status"
      exit 1
    fi
    echo "✅ Real experimental Cranelift extern-add-i32 native smoke passed."

guard-cranelift-extern-predicate-branch-i32-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling real experimental Cranelift extern-predicate-branch-i32 smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_EXTERN_PREDICATE_BRANCH_I32_NATIVE_GUARD: guard-cranelift-extern-predicate-branch-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_extern_predicate_branch_i32_native_guard: guard-cranelift-extern-predicate-branch-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_predicate_branch_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_predicate_branch_i32_object_artifact: build/guards/cranelift_extern_predicate_branch_i32_native/tiny_cranelift_extern_predicate_branch_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_predicate_branch_i32_host_symbol: tiny_host_is_positive_i32' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_extern_predicate_branch_i32_native
    object_file="build/guards/cranelift_extern_predicate_branch_i32_native/tiny_cranelift_extern_predicate_branch_i32.o"
    shim_c="build/guards/cranelift_extern_predicate_branch_i32_native/tiny_cranelift_extern_predicate_branch_i32_main.c"
    binary="build/guards/cranelift_extern_predicate_branch_i32_native/tiny_cranelift_extern_predicate_branch_i32_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- extern-predicate-branch-i32-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected Cranelift extern-predicate-branch-i32 object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'int32_t tiny_host_is_positive_i32(int32_t value) {' >> "$shim_c"
    printf '%s\n' '  return value > 0 ? 1 : 0;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_extern_predicate_branch_i32(int32_t value);' >> "$shim_c"
    printf '%s\n' 'int main(void) {' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_extern_predicate_branch_i32(4) != 11) {' >> "$shim_c"
    printf '%s\n' '    return 1;' >> "$shim_c"
    printf '%s\n' '  }' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_extern_predicate_branch_i32(0) != 13) {' >> "$shim_c"
    printf '%s\n' '    return 2;' >> "$shim_c"
    printf '%s\n' '  }' >> "$shim_c"
    printf '%s\n' '  return 10;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "10" ]; then
      echo "Expected real experimental Cranelift extern-predicate-branch-i32 native smoke to exit with status 10, got $status"
      exit 1
    fi
    echo "✅ Real experimental Cranelift extern-predicate-branch-i32 native smoke passed."

guard-cranelift-mir-return-int-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift return-int lowering smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_RETURN_INT_NATIVE_GUARD: guard-cranelift-mir-return-int-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_return_int_native_guard: guard-cranelift-mir-return-int-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_return_int_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_return_int_object_artifact: build/guards/cranelift_mir_return_int_native/tiny_cranelift_mir_return_int.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_return_int_symbol: tiny_cranelift_mir_return_int' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_return_int_lowering_scaffold: TinyMirFunction' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_mir_return_int_native
    object_file="build/guards/cranelift_mir_return_int_native/tiny_cranelift_mir_return_int.o"
    shim_c="build/guards/cranelift_mir_return_int_native/tiny_cranelift_mir_return_int_main.c"
    binary="build/guards/cranelift_mir_return_int_native/tiny_cranelift_mir_return_int_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-return-int-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected MIR-shaped Cranelift return-int object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_mir_return_int(void);' >> "$shim_c"
    printf '%s\n' 'int main(void) { return tiny_cranelift_mir_return_int(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "1" ]; then
      echo "Expected MIR-shaped Cranelift return-int native smoke to exit with status 1, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift return-int native smoke passed."

guard-cranelift-mir-local-binding-read-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift local-binding/read lowering smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_LOCAL_BINDING_READ_NATIVE_GUARD: guard-cranelift-mir-local-binding-read-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_local_binding_read_native_guard: guard-cranelift-mir-local-binding-read-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_local_binding_read_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_local_binding_read_object_artifact: build/guards/cranelift_mir_local_binding_read_native/tiny_cranelift_mir_local_binding_read.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_local_binding_read_symbol: tiny_cranelift_mir_local_binding_read' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_local_binding_read_lowering_scaffold: TinyMirStatement::LocalI32Set' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_mir_local_binding_read_native
    object_file="build/guards/cranelift_mir_local_binding_read_native/tiny_cranelift_mir_local_binding_read.o"
    shim_c="build/guards/cranelift_mir_local_binding_read_native/tiny_cranelift_mir_local_binding_read_main.c"
    binary="build/guards/cranelift_mir_local_binding_read_native/tiny_cranelift_mir_local_binding_read_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-local-binding-read-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected MIR-shaped Cranelift local-binding/read object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_mir_local_binding_read(void);' >> "$shim_c"
    printf '%s\n' 'int main(void) { return tiny_cranelift_mir_local_binding_read(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "2" ]; then
      echo "Expected MIR-shaped Cranelift local-binding/read native smoke to exit with status 2, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift local-binding/read native smoke passed."

guard-cranelift-mir-conditional-branch-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift conditional-branch lowering smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_CONDITIONAL_BRANCH_NATIVE_GUARD: guard-cranelift-mir-conditional-branch-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_conditional_branch_native_guard: guard-cranelift-mir-conditional-branch-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_conditional_branch_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_conditional_branch_object_artifact: build/guards/cranelift_mir_conditional_branch_native/tiny_cranelift_mir_conditional_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_conditional_branch_symbol: tiny_cranelift_mir_conditional_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_conditional_branch_lowering_scaffold: TinyMirTerminator::BranchI32Literal' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_mir_conditional_branch_native
    object_file="build/guards/cranelift_mir_conditional_branch_native/tiny_cranelift_mir_conditional_branch.o"
    shim_c="build/guards/cranelift_mir_conditional_branch_native/tiny_cranelift_mir_conditional_branch_main.c"
    binary="build/guards/cranelift_mir_conditional_branch_native/tiny_cranelift_mir_conditional_branch_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-conditional-branch-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected MIR-shaped Cranelift conditional-branch object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_mir_conditional_branch(void);' >> "$shim_c"
    printf '%s\n' 'int main(void) { return tiny_cranelift_mir_conditional_branch(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "1" ]; then
      echo "Expected MIR-shaped Cranelift conditional-branch native smoke to exit with status 1, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift conditional-branch native smoke passed."

guard-cranelift-mir-add-i32-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift add-i32 lowering smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_ADD_I32_NATIVE_GUARD: guard-cranelift-mir-add-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_add_i32_native_guard: guard-cranelift-mir-add-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_add_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_add_i32_object_artifact: build/guards/cranelift_mir_add_i32_native/tiny_cranelift_mir_add_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_add_i32_symbol: tiny_cranelift_mir_add_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_add_i32_lowering_scaffold: TinyMirTerminator::ReturnParamI32Add' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_mir_add_i32_native
    object_file="build/guards/cranelift_mir_add_i32_native/tiny_cranelift_mir_add_i32.o"
    shim_c="build/guards/cranelift_mir_add_i32_native/tiny_cranelift_mir_add_i32_main.c"
    binary="build/guards/cranelift_mir_add_i32_native/tiny_cranelift_mir_add_i32_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-add-i32-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected MIR-shaped Cranelift add-i32 object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_mir_add_i32(int32_t lhs, int32_t rhs);' >> "$shim_c"
    printf '%s\n' 'int main(void) {' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_add_i32(2, 3) != 5) return 1;' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_add_i32(0, 4) != 4) return 2;' >> "$shim_c"
    printf '%s\n' '  return 12;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "12" ]; then
      echo "Expected MIR-shaped Cranelift add-i32 native smoke to exit with status 12, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift add-i32 native smoke passed."

guard-cranelift-mir-positive-i32-branch-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift positive-i32-branch lowering smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_POSITIVE_I32_BRANCH_NATIVE_GUARD: guard-cranelift-mir-positive-i32-branch-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_positive_i32_branch_native_guard: guard-cranelift-mir-positive-i32-branch-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_positive_i32_branch_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_positive_i32_branch_object_artifact: build/guards/cranelift_mir_positive_i32_branch_native/tiny_cranelift_mir_positive_i32_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_positive_i32_branch_symbol: tiny_cranelift_mir_positive_i32_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_positive_i32_branch_lowering_scaffold: TinyMirTerminator::BranchParamI32Positive' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_mir_positive_i32_branch_native
    object_file="build/guards/cranelift_mir_positive_i32_branch_native/tiny_cranelift_mir_positive_i32_branch.o"
    shim_c="build/guards/cranelift_mir_positive_i32_branch_native/tiny_cranelift_mir_positive_i32_branch_main.c"
    binary="build/guards/cranelift_mir_positive_i32_branch_native/tiny_cranelift_mir_positive_i32_branch_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-positive-i32-branch-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected MIR-shaped Cranelift positive-i32-branch object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_mir_positive_i32_branch(int32_t value);' >> "$shim_c"
    printf '%s\n' 'int main(void) {' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_positive_i32_branch(1) != 7) return 1;' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_positive_i32_branch(0) != 9) return 2;' >> "$shim_c"
    printf '%s\n' '  return 13;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "13" ]; then
      echo "Expected MIR-shaped Cranelift positive-i32-branch native smoke to exit with status 13, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift positive-i32-branch native smoke passed."

guard-cranelift-mir-increment-local-i32-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift increment-local-i32 lowering smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_INCREMENT_LOCAL_I32_NATIVE_GUARD: guard-cranelift-mir-increment-local-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_increment_local_i32_native_guard: guard-cranelift-mir-increment-local-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_increment_local_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_increment_local_i32_object_artifact: build/guards/cranelift_mir_increment_local_i32_native/tiny_cranelift_mir_increment_local_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_increment_local_i32_symbol: tiny_cranelift_mir_increment_local_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_increment_local_i32_lowering_scaffold: TinyMirStatement::LocalI32SetParam+TinyMirStatement::LocalI32AddI32Literal' "$manifest_doc" >/dev/null
    mkdir -p build/guards/cranelift_mir_increment_local_i32_native
    object_file="build/guards/cranelift_mir_increment_local_i32_native/tiny_cranelift_mir_increment_local_i32.o"
    shim_c="build/guards/cranelift_mir_increment_local_i32_native/tiny_cranelift_mir_increment_local_i32_main.c"
    binary="build/guards/cranelift_mir_increment_local_i32_native/tiny_cranelift_mir_increment_local_i32_bin"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-increment-local-i32-object "$object_file"
    if [ ! -s "$object_file" ]; then
      echo "Expected MIR-shaped Cranelift increment-local-i32 object file to be generated at $object_file"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_mir_increment_local_i32(int32_t value);' >> "$shim_c"
    printf '%s\n' 'int main(void) {' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_increment_local_i32(4) != 5) return 1;' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_increment_local_i32(0) != 1) return 2;' >> "$shim_c"
    printf '%s\n' '  return 14;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "14" ]; then
      echo "Expected MIR-shaped Cranelift increment-local-i32 native smoke to exit with status 14, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift increment-local-i32 native smoke passed."

guard-cranelift-mir-call-helper-i32-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift helper-call lowering smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_CALL_HELPER_I32_NATIVE_GUARD: guard-cranelift-mir-call-helper-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_call_helper_i32_native_guard: guard-cranelift-mir-call-helper-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_call_helper_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_call_helper_i32_object_artifact: build/guards/cranelift_mir_call_helper_i32_native/tiny_cranelift_mir_call_helper_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_call_helper_i32_symbol: tiny_cranelift_mir_call_helper_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_call_helper_i32_helper_symbol: tiny_cranelift_mir_add_one_helper_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_call_helper_i32_lowering_scaffold: TinyMirTerminator::ReturnLocalFunctionI32Call' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_call_helper_i32_native"
    object_file="$build_dir/tiny_cranelift_mir_call_helper_i32.o"
    shim_c="$build_dir/tiny_cranelift_mir_call_helper_i32_main.c"
    binary="$build_dir/tiny_cranelift_mir_call_helper_i32_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-call-helper-i32-object "$object_file"
    test -s "$object_file"
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_mir_call_helper_i32(int32_t value);' >> "$shim_c"
    printf '%s\n' 'int main(void) {' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_call_helper_i32(4) != 5) return 1;' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_call_helper_i32(0) != 1) return 2;' >> "$shim_c"
    printf '%s\n' '  return 15;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "15" ]; then
      echo "Expected MIR-shaped Cranelift helper-call native smoke to exit with status 15, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift helper-call native smoke passed."
guard-cranelift-mir-extern-call-i32-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift imported host-call lowering smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_EXTERN_CALL_I32_NATIVE_GUARD: guard-cranelift-mir-extern-call-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_extern_call_i32_native_guard: guard-cranelift-mir-extern-call-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_extern_call_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_extern_call_i32_object_artifact: build/guards/cranelift_mir_extern_call_i32_native/tiny_cranelift_mir_extern_call_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_extern_call_i32_symbol: tiny_cranelift_mir_extern_call_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_extern_call_i32_host_symbol: tiny_host_add_one_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_extern_call_i32_lowering_scaffold: TinyMirTerminator::ReturnImportedFunctionI32Call' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_extern_call_i32_native"
    object_file="$build_dir/tiny_cranelift_mir_extern_call_i32.o"
    shim_c="$build_dir/tiny_cranelift_mir_extern_call_i32_main.c"
    binary="$build_dir/tiny_cranelift_mir_extern_call_i32_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-extern-call-i32-object "$object_file"
    test -s "$object_file"
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'int32_t tiny_host_add_one_i32(int32_t value) {' >> "$shim_c"
    printf '%s\n' '  return value + 1;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_mir_extern_call_i32(int32_t value);' >> "$shim_c"
    printf '%s\n' 'int main(void) {' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_extern_call_i32(4) != 5) return 1;' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_extern_call_i32(0) != 1) return 2;' >> "$shim_c"
    printf '%s\n' '  return 16;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "16" ]; then
      echo "Expected MIR-shaped Cranelift imported host-call native smoke to exit with status 16, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift imported host-call native smoke passed."

guard-cranelift-mir-extern-add-i32-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift multi-argument imported host-call lowering smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_EXTERN_ADD_I32_NATIVE_GUARD: guard-cranelift-mir-extern-add-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_extern_add_i32_native_guard: guard-cranelift-mir-extern-add-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_extern_add_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_extern_add_i32_object_artifact: build/guards/cranelift_mir_extern_add_i32_native/tiny_cranelift_mir_extern_add_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_extern_add_i32_symbol: tiny_cranelift_mir_extern_add_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_extern_add_i32_host_symbol: tiny_host_add_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_extern_add_i32_lowering_scaffold: TinyMirTerminator::ReturnImportedFunctionI32CallParamLiteral' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_extern_add_i32_native"
    object_file="$build_dir/tiny_cranelift_mir_extern_add_i32.o"
    shim_c="$build_dir/tiny_cranelift_mir_extern_add_i32_main.c"
    binary="$build_dir/tiny_cranelift_mir_extern_add_i32_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-extern-add-i32-object "$object_file"
    test -s "$object_file"
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'int32_t tiny_host_add_i32(int32_t lhs, int32_t rhs) {' >> "$shim_c"
    printf '%s\n' '  return lhs + rhs;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_mir_extern_add_i32(int32_t value);' >> "$shim_c"
    printf '%s\n' 'int main(void) {' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_extern_add_i32(4) != 7) return 1;' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_extern_add_i32(0) != 3) return 2;' >> "$shim_c"
    printf '%s\n' '  return 17;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "17" ]; then
      echo "Expected MIR-shaped Cranelift multi-argument imported host-call native smoke to exit with status 17, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift multi-argument imported host-call native smoke passed."

guard-cranelift-mir-extern-predicate-branch-i32-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift imported predicate branch lowering smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_EXTERN_PREDICATE_BRANCH_I32_NATIVE_GUARD: guard-cranelift-mir-extern-predicate-branch-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_extern_predicate_branch_i32_native_guard: guard-cranelift-mir-extern-predicate-branch-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_extern_predicate_branch_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_extern_predicate_branch_i32_object_artifact: build/guards/cranelift_mir_extern_predicate_branch_i32_native/tiny_cranelift_mir_extern_predicate_branch_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_extern_predicate_branch_i32_symbol: tiny_cranelift_mir_extern_predicate_branch_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_extern_predicate_branch_i32_host_symbol: tiny_host_is_positive_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_extern_predicate_branch_i32_lowering_scaffold: TinyMirTerminator::BranchImportedFunctionI32Predicate' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_extern_predicate_branch_i32_native"
    object_file="$build_dir/tiny_cranelift_mir_extern_predicate_branch_i32.o"
    shim_c="$build_dir/tiny_cranelift_mir_extern_predicate_branch_i32_main.c"
    binary="$build_dir/tiny_cranelift_mir_extern_predicate_branch_i32_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-extern-predicate-branch-i32-object "$object_file"
    test -s "$object_file"
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'int32_t tiny_host_is_positive_i32(int32_t value) {' >> "$shim_c"
    printf '%s\n' '  return value > 0 ? 1 : 0;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_mir_extern_predicate_branch_i32(int32_t value);' >> "$shim_c"
    printf '%s\n' 'int main(void) {' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_extern_predicate_branch_i32(4) != 11) return 1;' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_extern_predicate_branch_i32(0) != 13) return 2;' >> "$shim_c"
    printf '%s\n' '  return 18;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "18" ]; then
      echo "Expected MIR-shaped Cranelift imported predicate branch native smoke to exit with status 18, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift imported predicate branch native smoke passed."

guard-cranelift-differential-native-smoke:
    just guard-cranelift-mir-to-c-differential-native-smoke

guard-cranelift-mir-arithmetic-i32-bundle-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift arithmetic i32 bundle smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_ARITHMETIC_I32_BUNDLE_NATIVE_GUARD: guard-cranelift-mir-arithmetic-i32-bundle-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_arithmetic_i32_bundle_native_guard: guard-cranelift-mir-arithmetic-i32-bundle-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_arithmetic_i32_bundle_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_arithmetic_i32_bundle_object_artifact: build/guards/cranelift_mir_arithmetic_i32_bundle_native/tiny_cranelift_mir_arithmetic_i32_bundle.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_arithmetic_i32_bundle_sub_symbol: tiny_cranelift_mir_arithmetic_sub_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_arithmetic_i32_bundle_mul_symbol: tiny_cranelift_mir_arithmetic_mul_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_arithmetic_i32_bundle_lowering_scaffold: TinyMirTerminator::ReturnParamI32Sub' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_arithmetic_i32_bundle_lowering_scaffold: TinyMirTerminator::ReturnParamI32Mul' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_arithmetic_i32_bundle_native"
    object_file="$build_dir/tiny_cranelift_mir_arithmetic_i32_bundle.o"
    shim_c="$build_dir/tiny_cranelift_mir_arithmetic_i32_bundle_main.c"
    binary="$build_dir/tiny_cranelift_mir_arithmetic_i32_bundle_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-arithmetic-i32-bundle-object "$object_file"
    test -s "$object_file"
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_mir_arithmetic_sub_i32(int32_t lhs, int32_t rhs);' >> "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_mir_arithmetic_mul_i32(int32_t lhs, int32_t rhs);' >> "$shim_c"
    printf '%s\n' 'int main(void) {' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_arithmetic_sub_i32(7, 2) != 5) return 1;' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_arithmetic_sub_i32(2, 7) != -5) return 2;' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_arithmetic_mul_i32(3, 4) != 12) return 3;' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_arithmetic_mul_i32(-3, 4) != -12) return 4;' >> "$shim_c"
    printf '%s\n' '  return 14;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "14" ]; then
      echo "Expected MIR-shaped Cranelift arithmetic i32 bundle native smoke to exit with status 14, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift arithmetic i32 bundle native smoke passed."

guard-cranelift-mir-comparison-i32-bundle-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift comparison i32 bundle smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_COMPARISON_I32_BUNDLE_NATIVE_GUARD: guard-cranelift-mir-comparison-i32-bundle-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_comparison_i32_bundle_native_guard: guard-cranelift-mir-comparison-i32-bundle-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_comparison_i32_bundle_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_comparison_i32_bundle_object_artifact: build/guards/cranelift_mir_comparison_i32_bundle_native/tiny_cranelift_mir_comparison_i32_bundle.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_comparison_i32_bundle_eq_symbol: tiny_cranelift_mir_comparison_eq_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_comparison_i32_bundle_sgt_symbol: tiny_cranelift_mir_comparison_sgt_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_comparison_i32_bundle_lowering_scaffold: TinyMirTerminator::ReturnParamI32EqPredicate' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_comparison_i32_bundle_lowering_scaffold: TinyMirTerminator::ReturnParamI32SignedGreaterThanPredicate' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_comparison_i32_bundle_native"
    object_file="$build_dir/tiny_cranelift_mir_comparison_i32_bundle.o"
    shim_c="$build_dir/tiny_cranelift_mir_comparison_i32_bundle_main.c"
    binary="$build_dir/tiny_cranelift_mir_comparison_i32_bundle_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-comparison-i32-bundle-object "$object_file"
    test -s "$object_file"
    printf '%s\n' '#include <stdint.h>' > "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_mir_comparison_eq_i32(int32_t lhs, int32_t rhs);' >> "$shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_mir_comparison_sgt_i32(int32_t lhs, int32_t rhs);' >> "$shim_c"
    printf '%s\n' 'int main(void) {' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_comparison_eq_i32(4, 4) != 1) return 1;' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_comparison_eq_i32(4, 5) != 0) return 2;' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_comparison_sgt_i32(7, 2) != 1) return 3;' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_comparison_sgt_i32(2, 7) != 0) return 4;' >> "$shim_c"
    printf '%s\n' '  if (tiny_cranelift_mir_comparison_sgt_i32(-2, -7) != 1) return 5;' >> "$shim_c"
    printf '%s\n' '  return 15;' >> "$shim_c"
    printf '%s\n' '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "15" ]; then
      echo "Expected MIR-shaped Cranelift comparison i32 bundle native smoke to exit with status 15, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift comparison i32 bundle native smoke passed."

guard-cranelift-mir-comparison-branch-i32-bundle-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift comparison-branch i32 bundle smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_COMPARISON_BRANCH_I32_BUNDLE_NATIVE_GUARD: guard-cranelift-mir-comparison-branch-i32-bundle-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_comparison_branch_i32_bundle_native_guard: guard-cranelift-mir-comparison-branch-i32-bundle-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_comparison_branch_i32_bundle_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_comparison_branch_i32_bundle_object_artifact: build/guards/cranelift_mir_comparison_branch_i32_bundle_native/tiny_cranelift_mir_comparison_branch_i32_bundle.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_comparison_branch_i32_bundle_eq_symbol: tiny_cranelift_mir_comparison_branch_eq_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_comparison_branch_i32_bundle_sgt_symbol: tiny_cranelift_mir_comparison_branch_sgt_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_comparison_branch_i32_bundle_lowering_scaffold: TinyMirTerminator::BranchParamI32Eq' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_comparison_branch_i32_bundle_lowering_scaffold: TinyMirTerminator::BranchParamI32SignedGreaterThan' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_comparison_branch_i32_bundle_native"
    object_file="$build_dir/tiny_cranelift_mir_comparison_branch_i32_bundle.o"
    shim_c="$build_dir/tiny_cranelift_mir_comparison_branch_i32_bundle_main.c"
    binary="$build_dir/tiny_cranelift_mir_comparison_branch_i32_bundle_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-comparison-branch-i32-bundle-object "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_comparison_branch_eq_i32(int32_t lhs, int32_t rhs);' >> "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_comparison_branch_sgt_i32(int32_t lhs, int32_t rhs);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_comparison_branch_eq_i32(5, 5) != 21) return 1;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_comparison_branch_eq_i32(5, 6) != 22) return 2;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_comparison_branch_sgt_i32(9, 4) != 23) return 3;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_comparison_branch_sgt_i32(4, 9) != 24) return 4;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_comparison_branch_sgt_i32(-2, -7) != 23) return 5;' >> "$shim_c"
    echo '  return 16;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "16" ]; then
      echo "Expected MIR-shaped Cranelift comparison-branch i32 bundle native smoke to exit with status 16, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift comparison-branch i32 bundle native smoke passed."

guard-cranelift-mir-block-graph-i32-bundle-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift block graph i32 bundle smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_BLOCK_GRAPH_I32_BUNDLE_NATIVE_GUARD: guard-cranelift-mir-block-graph-i32-bundle-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_block_graph_i32_bundle_native_guard: guard-cranelift-mir-block-graph-i32-bundle-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_i32_bundle_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_i32_bundle_object_artifact: build/guards/cranelift_mir_block_graph_i32_bundle_native/tiny_cranelift_mir_block_graph_i32_bundle.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_i32_bundle_jump_symbol: tiny_cranelift_mir_block_graph_jump_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_i32_bundle_branch_symbol: tiny_cranelift_mir_block_graph_branch_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_i32_bundle_lowering_scaffold: TinyMirBlock' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_i32_bundle_lowering_scaffold: TinyMirBlockTerminator::Jump' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_i32_bundle_lowering_scaffold: TinyMirBlockTerminator::BranchParamI32Positive' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_block_graph_i32_bundle_native"
    object_file="$build_dir/tiny_cranelift_mir_block_graph_i32_bundle.o"
    shim_c="$build_dir/tiny_cranelift_mir_block_graph_i32_bundle_main.c"
    binary="$build_dir/tiny_cranelift_mir_block_graph_i32_bundle_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-block-graph-i32-bundle-object "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_jump_i32(void);' >> "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_branch_i32(int32_t value);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_jump_i32() != 29) return 1;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_branch_i32(3) != 31) return 2;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_branch_i32(0) != 37) return 3;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_branch_i32(-1) != 37) return 4;' >> "$shim_c"
    echo '  return 17;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "17" ]; then
      echo "Expected MIR-shaped Cranelift block graph i32 bundle native smoke to exit with status 17, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift block graph i32 bundle native smoke passed."

guard-cranelift-mir-block-graph-local-i32-bundle-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift block graph local i32 bundle smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_BLOCK_GRAPH_LOCAL_I32_BUNDLE_NATIVE_GUARD: guard-cranelift-mir-block-graph-local-i32-bundle-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_i32_bundle_native_guard: guard-cranelift-mir-block-graph-local-i32-bundle-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_i32_bundle_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_i32_bundle_object_artifact: build/guards/cranelift_mir_block_graph_local_i32_bundle_native/tiny_cranelift_mir_block_graph_local_i32_bundle.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_i32_bundle_local_read_symbol: tiny_cranelift_mir_block_graph_local_read_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_i32_bundle_local_branch_symbol: tiny_cranelift_mir_block_graph_local_branch_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_i32_bundle_lowering_scaffold: TinyMirBlockStatement::LocalI32Set' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_i32_bundle_lowering_scaffold: TinyMirBlockStatement::LocalI32SetParam' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_i32_bundle_lowering_scaffold: TinyMirBlockTerminator::ReturnLocalI32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_i32_bundle_lowering_scaffold: TinyMirBlockTerminator::BranchLocalI32Positive' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_block_graph_local_i32_bundle_native"
    object_file="$build_dir/tiny_cranelift_mir_block_graph_local_i32_bundle.o"
    shim_c="$build_dir/tiny_cranelift_mir_block_graph_local_i32_bundle_main.c"
    binary="$build_dir/tiny_cranelift_mir_block_graph_local_i32_bundle_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-block-graph-local-i32-bundle-object "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_local_read_i32(void);' >> "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_local_branch_i32(int32_t value);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_local_read_i32() != 41) return 1;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_local_branch_i32(9) != 43) return 2;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_local_branch_i32(0) != 47) return 3;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_local_branch_i32(-3) != 47) return 4;' >> "$shim_c"
    echo '  return 18;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "18" ]; then
      echo "Expected MIR-shaped Cranelift block graph local i32 bundle native smoke to exit with status 18, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift block graph local i32 bundle native smoke passed."

guard-cranelift-mir-block-graph-local-update-i32-bundle-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift block graph local update i32 bundle smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_BLOCK_GRAPH_LOCAL_UPDATE_I32_BUNDLE_NATIVE_GUARD: guard-cranelift-mir-block-graph-local-update-i32-bundle-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_update_i32_bundle_native_guard: guard-cranelift-mir-block-graph-local-update-i32-bundle-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_update_i32_bundle_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_update_i32_bundle_object_artifact: build/guards/cranelift_mir_block_graph_local_update_i32_bundle_native/tiny_cranelift_mir_block_graph_local_update_i32_bundle.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_update_i32_bundle_local_update_symbol: tiny_cranelift_mir_block_graph_local_update_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_update_i32_bundle_local_update_branch_symbol: tiny_cranelift_mir_block_graph_local_update_branch_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_update_i32_bundle_lowering_scaffold: TinyMirBlockStatement::LocalI32AddI32Literal' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_update_i32_bundle_lowering_scaffold: TinyMirBlockTerminator::Jump' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_update_i32_bundle_lowering_scaffold: TinyMirBlockTerminator::ReturnLocalI32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_local_update_i32_bundle_lowering_scaffold: TinyMirBlockTerminator::BranchLocalI32Positive' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_block_graph_local_update_i32_bundle_native"
    object_file="$build_dir/tiny_cranelift_mir_block_graph_local_update_i32_bundle.o"
    shim_c="$build_dir/tiny_cranelift_mir_block_graph_local_update_i32_bundle_main.c"
    binary="$build_dir/tiny_cranelift_mir_block_graph_local_update_i32_bundle_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-block-graph-local-update-i32-bundle-object "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_local_update_i32(void);' >> "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_local_update_branch_i32(int32_t value);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_local_update_i32() != 45) return 1;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_local_update_branch_i32(-3) != 59) return 2;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_local_update_branch_i32(-1) != 53) return 3;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_local_update_branch_i32(0) != 53) return 4;' >> "$shim_c"
    echo '  return 19;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "19" ]; then
      echo "Expected MIR-shaped Cranelift block graph local update i32 bundle native smoke to exit with status 19, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift block graph local update i32 bundle native smoke passed."

guard-cranelift-mir-block-graph-param-i32-bundle-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift block graph parameter i32 bundle smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_BLOCK_GRAPH_PARAM_I32_BUNDLE_NATIVE_GUARD: guard-cranelift-mir-block-graph-param-i32-bundle-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_i32_bundle_native_guard: guard-cranelift-mir-block-graph-param-i32-bundle-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_i32_bundle_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_i32_bundle_object_artifact: build/guards/cranelift_mir_block_graph_param_i32_bundle_native/tiny_cranelift_mir_block_graph_param_i32_bundle.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_i32_bundle_param_forward_symbol: tiny_cranelift_mir_block_graph_param_forward_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_i32_bundle_param_update_branch_symbol: tiny_cranelift_mir_block_graph_param_update_branch_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_i32_bundle_lowering_scaffold: TinyMirParamBlock' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::JumpI32Literal' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::JumpFunctionParamI32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::BranchBlockParamI32Positive' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::ReturnBlockParamI32' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_block_graph_param_i32_bundle_native"
    object_file="$build_dir/tiny_cranelift_mir_block_graph_param_i32_bundle.o"
    shim_c="$build_dir/tiny_cranelift_mir_block_graph_param_i32_bundle_main.c"
    binary="$build_dir/tiny_cranelift_mir_block_graph_param_i32_bundle_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-block-graph-param-i32-bundle-object "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_param_forward_i32(void);' >> "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_param_update_branch_i32(int32_t value);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_forward_i32() != 53) return 1;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_update_branch_i32(-5) != 71) return 2;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_update_branch_i32(-4) != 71) return 3;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_update_branch_i32(-3) != 67) return 4;' >> "$shim_c"
    echo '  return 23;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "23" ]; then
      echo "Expected MIR-shaped Cranelift block graph parameter i32 bundle native smoke to exit with status 23, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift block graph parameter i32 bundle native smoke passed."

guard-cranelift-mir-block-graph-param-call-i32-bundle-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift block graph parameter call i32 bundle smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_BLOCK_GRAPH_PARAM_CALL_I32_BUNDLE_NATIVE_GUARD: guard-cranelift-mir-block-graph-param-call-i32-bundle-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_call_i32_bundle_native_guard: guard-cranelift-mir-block-graph-param-call-i32-bundle-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_call_i32_bundle_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_call_i32_bundle_object_artifact: build/guards/cranelift_mir_block_graph_param_call_i32_bundle_native/tiny_cranelift_mir_block_graph_param_call_i32_bundle.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_call_i32_bundle_param_call_symbol: tiny_cranelift_mir_block_graph_param_call_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_call_i32_bundle_param_call_branch_symbol: tiny_cranelift_mir_block_graph_param_call_branch_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_call_i32_bundle_helper_symbol: tiny_cranelift_mir_block_graph_param_add_one_helper_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_call_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::ReturnBlockParamLocalFunctionI32Call' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_call_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::BranchBlockParamLocalFunctionI32CallPositive' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_block_graph_param_call_i32_bundle_native"
    object_file="$build_dir/tiny_cranelift_mir_block_graph_param_call_i32_bundle.o"
    shim_c="$build_dir/tiny_cranelift_mir_block_graph_param_call_i32_bundle_main.c"
    binary="$build_dir/tiny_cranelift_mir_block_graph_param_call_i32_bundle_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-block-graph-param-call-i32-bundle-object "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_param_call_i32(int32_t value);' >> "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_param_call_branch_i32(int32_t value);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_call_i32(60) != 61) return 1;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_call_i32(-2) != -1) return 2;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_call_branch_i32(0) != 79) return 3;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_call_branch_i32(-2) != 83) return 4;' >> "$shim_c"
    echo '  return 89;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "89" ]; then
      echo "Expected MIR-shaped Cranelift block graph parameter call i32 bundle native smoke to exit with status 89, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift block graph parameter call i32 bundle native smoke passed."

guard-cranelift-mir-block-graph-param-extern-i32-bundle-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift block graph parameter extern i32 bundle smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_BLOCK_GRAPH_PARAM_EXTERN_I32_BUNDLE_NATIVE_GUARD: guard-cranelift-mir-block-graph-param-extern-i32-bundle-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_i32_bundle_native_guard: guard-cranelift-mir-block-graph-param-extern-i32-bundle-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_i32_bundle_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_i32_bundle_object_artifact: build/guards/cranelift_mir_block_graph_param_extern_i32_bundle_native/tiny_cranelift_mir_block_graph_param_extern_i32_bundle.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_i32_bundle_param_extern_call_symbol: tiny_cranelift_mir_block_graph_param_extern_call_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_i32_bundle_param_extern_call_branch_symbol: tiny_cranelift_mir_block_graph_param_extern_call_branch_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_i32_bundle_host_symbol: tiny_host_add_one_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32Call' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallPositive' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_block_graph_param_extern_i32_bundle_native"
    object_file="$build_dir/tiny_cranelift_mir_block_graph_param_extern_i32_bundle.o"
    shim_c="$build_dir/tiny_cranelift_mir_block_graph_param_extern_i32_bundle_main.c"
    binary="$build_dir/tiny_cranelift_mir_block_graph_param_extern_i32_bundle_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-block-graph-param-extern-i32-bundle-object "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_host_add_one_i32(int32_t value) { return value + 1; }' >> "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_param_extern_call_i32(int32_t value);' >> "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_param_extern_call_branch_i32(int32_t value);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_extern_call_i32(70) != 71) return 1;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_extern_call_i32(-2) != -1) return 2;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_extern_call_branch_i32(0) != 101) return 3;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_extern_call_branch_i32(-2) != 103) return 4;' >> "$shim_c"
    echo '  return 97;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "97" ]; then
      echo "Expected MIR-shaped Cranelift block graph parameter extern i32 bundle native smoke to exit with status 97, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift block graph parameter extern i32 bundle native smoke passed."

guard-cranelift-mir-block-graph-param-extern-add-i32-bundle-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift block graph parameter extern add i32 bundle smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_BLOCK_GRAPH_PARAM_EXTERN_ADD_I32_BUNDLE_NATIVE_GUARD: guard-cranelift-mir-block-graph-param-extern-add-i32-bundle-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_add_i32_bundle_native_guard: guard-cranelift-mir-block-graph-param-extern-add-i32-bundle-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_add_i32_bundle_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_add_i32_bundle_object_artifact: build/guards/cranelift_mir_block_graph_param_extern_add_i32_bundle_native/tiny_cranelift_mir_block_graph_param_extern_add_i32_bundle.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_add_i32_bundle_param_extern_add_symbol: tiny_cranelift_mir_block_graph_param_extern_add_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_add_i32_bundle_param_extern_add_branch_symbol: tiny_cranelift_mir_block_graph_param_extern_add_branch_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_add_i32_bundle_host_symbol: tiny_host_add_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_add_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_add_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallI32LiteralPositive' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_block_graph_param_extern_add_i32_bundle_native"
    object_file="$build_dir/tiny_cranelift_mir_block_graph_param_extern_add_i32_bundle.o"
    shim_c="$build_dir/tiny_cranelift_mir_block_graph_param_extern_add_i32_bundle_main.c"
    binary="$build_dir/tiny_cranelift_mir_block_graph_param_extern_add_i32_bundle_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-block-graph-param-extern-add-i32-bundle-object "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_host_add_i32(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_param_extern_add_i32(int32_t value);' >> "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_param_extern_add_branch_i32(int32_t value);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_extern_add_i32(80) != 85) return 1;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_extern_add_i32(-10) != -5) return 2;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_extern_add_branch_i32(3) != 107) return 3;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_extern_add_branch_i32(1) != 109) return 4;' >> "$shim_c"
    echo '  return 113;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "113" ]; then
      echo "Expected MIR-shaped Cranelift block graph parameter extern add i32 bundle native smoke to exit with status 113, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift block graph parameter extern add i32 bundle native smoke passed."

guard-cranelift-mir-block-graph-param-extern-predicate-i32-bundle-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift block graph parameter extern predicate i32 bundle smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_BLOCK_GRAPH_PARAM_EXTERN_PREDICATE_I32_BUNDLE_NATIVE_GUARD: guard-cranelift-mir-block-graph-param-extern-predicate-i32-bundle-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_predicate_i32_bundle_native_guard: guard-cranelift-mir-block-graph-param-extern-predicate-i32-bundle-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_predicate_i32_bundle_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_predicate_i32_bundle_object_artifact: build/guards/cranelift_mir_block_graph_param_extern_predicate_i32_bundle_native/tiny_cranelift_mir_block_graph_param_extern_predicate_i32_bundle.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_predicate_i32_bundle_param_extern_predicate_symbol: tiny_cranelift_mir_block_graph_param_extern_predicate_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_predicate_i32_bundle_param_extern_predicate_update_branch_symbol: tiny_cranelift_mir_block_graph_param_extern_predicate_update_branch_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_predicate_i32_bundle_host_symbol: tiny_host_is_positive_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_extern_predicate_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32Predicate' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_block_graph_param_extern_predicate_i32_bundle_native"
    object_file="$build_dir/tiny_cranelift_mir_block_graph_param_extern_predicate_i32_bundle.o"
    shim_c="$build_dir/tiny_cranelift_mir_block_graph_param_extern_predicate_i32_bundle_main.c"
    binary="$build_dir/tiny_cranelift_mir_block_graph_param_extern_predicate_i32_bundle_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-block-graph-param-extern-predicate-i32-bundle-object "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_host_is_positive_i32(int32_t value) { return value > 0 ? 1 : 0; }' >> "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_param_extern_predicate_i32(int32_t value);' >> "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_param_extern_predicate_update_branch_i32(int32_t value);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_extern_predicate_i32(7) != 149) return 1;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_extern_predicate_i32(0) != 151) return 2;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_extern_predicate_update_branch_i32(9) != 157) return 3;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_extern_predicate_update_branch_i32(4) != 163) return 4;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_extern_predicate_update_branch_i32(-3) != 163) return 5;' >> "$shim_c"
    echo '  return 127;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "127" ]; then
      echo "Expected MIR-shaped Cranelift block graph parameter extern predicate i32 bundle native smoke to exit with status 127, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift block graph parameter extern predicate i32 bundle native smoke passed."

guard-cranelift-mir-block-graph-param-merge-i32-bundle-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift block graph parameter merge i32 bundle smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_BLOCK_GRAPH_PARAM_MERGE_I32_BUNDLE_NATIVE_GUARD: guard-cranelift-mir-block-graph-param-merge-i32-bundle-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_i32_bundle_native_guard: guard-cranelift-mir-block-graph-param-merge-i32-bundle-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_i32_bundle_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_i32_bundle_object_artifact: build/guards/cranelift_mir_block_graph_param_merge_i32_bundle_native/tiny_cranelift_mir_block_graph_param_merge_i32_bundle.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_i32_bundle_param_merge_symbol: tiny_cranelift_mir_block_graph_param_merge_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_i32_bundle_param_merge_update_symbol: tiny_cranelift_mir_block_graph_param_merge_update_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::ReturnBlockParamI32' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_block_graph_param_merge_i32_bundle_native"
    object_file="$build_dir/tiny_cranelift_mir_block_graph_param_merge_i32_bundle.o"
    shim_c="$build_dir/tiny_cranelift_mir_block_graph_param_merge_i32_bundle_main.c"
    binary="$build_dir/tiny_cranelift_mir_block_graph_param_merge_i32_bundle_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-block-graph-param-merge-i32-bundle-object "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_param_merge_i32(int32_t value);' >> "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_param_merge_update_i32(int32_t value);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_merge_i32(9) != 173) return 1;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_merge_i32(0) != 179) return 2;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_merge_i32(-9) != 179) return 3;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_merge_update_i32(0) != 181) return 4;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_merge_update_i32(-4) != 191) return 5;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_merge_update_i32(-9) != 191) return 6;' >> "$shim_c"
    echo '  return 43;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "43" ]; then
      echo "Expected MIR-shaped Cranelift block graph parameter merge i32 bundle native smoke to exit with status 43, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift block graph parameter merge i32 bundle native smoke passed."

guard-cranelift-mir-block-graph-param-merge-call-i32-bundle-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-shaped Cranelift block graph parameter merge call i32 bundle smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_BUNDLE_NATIVE_GUARD: guard-cranelift-mir-block-graph-param-merge-call-i32-bundle-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_call_i32_bundle_native_guard: guard-cranelift-mir-block-graph-param-merge-call-i32-bundle-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_call_i32_bundle_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_call_i32_bundle_object_artifact: build/guards/cranelift_mir_block_graph_param_merge_call_i32_bundle_native/tiny_cranelift_mir_block_graph_param_merge_call_i32_bundle.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_call_i32_bundle_param_merge_call_symbol: tiny_cranelift_mir_block_graph_param_merge_call_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_call_i32_bundle_param_merge_call_branch_symbol: tiny_cranelift_mir_block_graph_param_merge_call_branch_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_call_i32_bundle_helper_symbol: tiny_cranelift_mir_block_graph_param_merge_add_one_helper_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_call_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_call_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_call_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::ReturnBlockParamLocalFunctionI32Call' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_block_graph_param_merge_call_i32_bundle_lowering_scaffold: TinyMirParamBlockTerminator::BranchBlockParamLocalFunctionI32CallPositive' "$manifest_doc" >/dev/null
    build_dir="build/guards/cranelift_mir_block_graph_param_merge_call_i32_bundle_native"
    object_file="$build_dir/tiny_cranelift_mir_block_graph_param_merge_call_i32_bundle.o"
    shim_c="$build_dir/tiny_cranelift_mir_block_graph_param_merge_call_i32_bundle_main.c"
    binary="$build_dir/tiny_cranelift_mir_block_graph_param_merge_call_i32_bundle_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- mir-block-graph-param-merge-call-i32-bundle-object "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_param_merge_call_i32(int32_t value);' >> "$shim_c"
    echo 'extern int32_t tiny_cranelift_mir_block_graph_param_merge_call_branch_i32(int32_t value);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_merge_call_i32(9) != 198) return 1;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_merge_call_i32(0) != 200) return 2;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_merge_call_i32(-9) != 200) return 3;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_merge_call_branch_i32(5) != 227) return 4;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_merge_call_branch_i32(2) != 229) return 5;' >> "$shim_c"
    echo '  if (tiny_cranelift_mir_block_graph_param_merge_call_branch_i32(-7) != 229) return 6;' >> "$shim_c"
    echo '  return 44;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "44" ]; then
      echo "Expected MIR-shaped Cranelift block graph parameter merge call i32 bundle native smoke to exit with status 44, got $status"
      exit 1
    fi
    echo "✅ MIR-shaped Cranelift block graph parameter merge call i32 bundle native smoke passed."

guard-cranelift-compiler-mir-return-int-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR return-int ingestion seam smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_return_int_ingestion.mir"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_RETURN_INT_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-return-int-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_return_int_ingestion_native_guard: guard-cranelift-compiler-mir-return-int-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_return_int_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_return_int_ingestion_fixture: compiler/fixtures/native_backend_return_int_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_return_int_ingestion_fixture_producer: compiler/mir.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_return_int_ingestion_fixture_producer_entry: mir_emit_native_backend_return_int_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_return_int_ingestion_object_artifact: build/guards/cranelift_compiler_mir_return_int_ingestion_native/tiny_native_backend_compiler_mir_ingested_return_int.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_return_int_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_return_int' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_return_int_ingestion_source_fixture: compiler/mir_feature_return_int_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_return_int_ingestion_lowering_entry: mir_lower_return_int_literal_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_return_int_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_return_int_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'mir_lower_return_int_literal_fixture(ctx)' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.return_int.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer_entry: mir_emit_native_backend_return_int_ingestion_fixture' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'source_fixture: compiler/mir_feature_return_int_preservation_source.gst' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'lowering_entry: mir_lower_return_int_literal_fixture' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_return_int' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-return-int-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_return_int_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_RETURN_INT_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_return_int_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_return_int.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_return_int_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_return_int_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-return-int-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_return_int(void);' >> "$shim_c"
    echo 'int main(void) { return tiny_native_backend_compiler_mir_ingested_return_int(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "1" ]; then
      echo "Expected compiler-owned MIR return-int ingestion native smoke to exit with status 1, got $status"
      exit 1
    fi
    echo "✅ Compiler-owned MIR return-int ingestion seam native smoke passed."

guard-cranelift-mir-to-cranelift-return-int-translator-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-to-Cranelift return-int translator seed..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_return_int_ingestion.mir"
    just guard-cranelift-backend-surface
    just guard-mir-to-c-return-int-literal-native-smoke
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_TO_CRANELIFT_RETURN_INT_TRANSLATOR_NATIVE_GUARD: guard-cranelift-mir-to-cranelift-return-int-translator-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_return_int_translator_native_guard: guard-cranelift-mir-to-cranelift-return-int-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_return_int_translator_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_return_int_translator_command: compiler-mir-to-cranelift-return-int-translator-object' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_return_int_translator_input_fixture: compiler/fixtures/native_backend_return_int_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_return_int_translator_oracle_guard: guard-mir-to-c-return-int-literal-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_return_int_translator_translation_entry: translate_compiler_mir_return_int_fixture_to_tiny_mir_function' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_return_int_translator_object_artifact: build/guards/cranelift_mir_to_cranelift_return_int_translator_native/tiny_native_backend_mir_to_cranelift_return_int_translator.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_return_int_translator_symbol: tiny_native_backend_mir_to_cranelift_return_int_translator' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_return_int_translator_seam_status: phase9b_translator_seed_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.return_int.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'terminator: Return' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'return_value_kind: IntLiteral' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'return_value: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-to-cranelift-return-int-translator-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'translate_compiler_mir_return_int_fixture_to_tiny_mir_function' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_TO_CRANELIFT_RETURN_INT_TRANSLATOR_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_mir_to_cranelift_return_int_translator_native"
    object_file="$build_dir/tiny_native_backend_mir_to_cranelift_return_int_translator.o"
    shim_c="$build_dir/tiny_native_backend_mir_to_cranelift_return_int_translator_main.c"
    binary="$build_dir/tiny_native_backend_mir_to_cranelift_return_int_translator_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-to-cranelift-return-int-translator-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_mir_to_cranelift_return_int_translator(void);' >> "$shim_c"
    echo 'int main(void) { return tiny_native_backend_mir_to_cranelift_return_int_translator(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "1" ]; then
      echo "Expected MIR-to-Cranelift return-int translator seed native smoke to exit with status 1, got $status"
      exit 1
    fi
    echo "✅ MIR-to-Cranelift return-int translator seed native smoke passed."

guard-cranelift-mir-to-cranelift-local-binding-read-translator-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-to-Cranelift local-binding/read translator seed..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_local_binding_read_ingestion.mir"
    just guard-cranelift-backend-surface
    just guard-mir-to-c-local-binding-read-native-smoke
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_TO_CRANELIFT_LOCAL_BINDING_READ_TRANSLATOR_NATIVE_GUARD: guard-cranelift-mir-to-cranelift-local-binding-read-translator-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_local_binding_read_translator_native_guard: guard-cranelift-mir-to-cranelift-local-binding-read-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_local_binding_read_translator_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_local_binding_read_translator_command: compiler-mir-to-cranelift-local-binding-read-translator-object' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_local_binding_read_translator_input_fixture: compiler/fixtures/native_backend_local_binding_read_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_local_binding_read_translator_oracle_guard: guard-mir-to-c-local-binding-read-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_local_binding_read_translator_translation_entry: translate_compiler_mir_local_binding_read_fixture_to_tiny_mir_function' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_local_binding_read_translator_object_artifact: build/guards/cranelift_mir_to_cranelift_local_binding_read_translator_native/tiny_native_backend_mir_to_cranelift_local_binding_read_translator.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_local_binding_read_translator_symbol: tiny_native_backend_mir_to_cranelift_local_binding_read_translator' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_local_binding_read_translator_seam_status: phase9b_translator_seed_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.local_binding_read.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'statement_0_kind: LocalI32Set' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'statement_0_value: 2' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'return_local: value' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-to-cranelift-local-binding-read-translator-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'translate_compiler_mir_local_binding_read_fixture_to_tiny_mir_function' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_TO_CRANELIFT_LOCAL_BINDING_READ_TRANSLATOR_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_mir_to_cranelift_local_binding_read_translator_native"
    object_file="$build_dir/tiny_native_backend_mir_to_cranelift_local_binding_read_translator.o"
    shim_c="$build_dir/tiny_native_backend_mir_to_cranelift_local_binding_read_translator_main.c"
    binary="$build_dir/tiny_native_backend_mir_to_cranelift_local_binding_read_translator_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-to-cranelift-local-binding-read-translator-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_mir_to_cranelift_local_binding_read_translator(void);' >> "$shim_c"
    echo 'int main(void) { return tiny_native_backend_mir_to_cranelift_local_binding_read_translator(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "2" ]; then
      echo "Expected MIR-to-Cranelift local-binding/read translator seed native smoke to exit with status 2, got $status"
      exit 1
    fi
    echo "✅ MIR-to-Cranelift local-binding/read translator seed native smoke passed."

guard-cranelift-mir-to-cranelift-conditional-branch-translator-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-to-Cranelift conditional-branch translator seed..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_conditional_branch_ingestion.mir"
    just guard-cranelift-backend-surface
    just guard-mir-to-c-conditional-branch-native-smoke
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_TO_CRANELIFT_CONDITIONAL_BRANCH_TRANSLATOR_NATIVE_GUARD: guard-cranelift-mir-to-cranelift-conditional-branch-translator-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_conditional_branch_translator_native_guard: guard-cranelift-mir-to-cranelift-conditional-branch-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_conditional_branch_translator_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_conditional_branch_translator_command: compiler-mir-to-cranelift-conditional-branch-translator-object' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_conditional_branch_translator_input_fixture: compiler/fixtures/native_backend_conditional_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_conditional_branch_translator_oracle_guard: guard-mir-to-c-conditional-branch-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_conditional_branch_translator_translation_entry: translate_compiler_mir_conditional_branch_fixture_to_tiny_mir_function' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_conditional_branch_translator_object_artifact: build/guards/cranelift_mir_to_cranelift_conditional_branch_translator_native/tiny_native_backend_mir_to_cranelift_conditional_branch_translator.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_conditional_branch_translator_symbol: tiny_native_backend_mir_to_cranelift_conditional_branch_translator' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_conditional_branch_translator_seam_status: phase9b_translator_seed_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.conditional_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_count: 3' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_terminator: Branch' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_condition_value: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_return_value: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_return_value: 2' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-to-cranelift-conditional-branch-translator-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'translate_compiler_mir_conditional_branch_fixture_to_tiny_mir_function' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_TO_CRANELIFT_CONDITIONAL_BRANCH_TRANSLATOR_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_mir_to_cranelift_conditional_branch_translator_native"
    object_file="$build_dir/tiny_native_backend_mir_to_cranelift_conditional_branch_translator.o"
    shim_c="$build_dir/tiny_native_backend_mir_to_cranelift_conditional_branch_translator_main.c"
    binary="$build_dir/tiny_native_backend_mir_to_cranelift_conditional_branch_translator_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-to-cranelift-conditional-branch-translator-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_mir_to_cranelift_conditional_branch_translator(void);' >> "$shim_c"
    echo 'int main(void) { return tiny_native_backend_mir_to_cranelift_conditional_branch_translator(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "1" ]; then
      echo "Expected MIR-to-Cranelift conditional-branch translator seed native smoke to exit with status 1, got $status"
      exit 1
    fi
    echo "✅ MIR-to-Cranelift conditional-branch translator seed native smoke passed."

guard-cranelift-mir-to-cranelift-block-jump-translator-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-to-Cranelift block-jump translator seed..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_jump_ingestion.mir"
    just guard-cranelift-backend-surface
    just guard-mir-to-c-block-jump-native-smoke
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_TO_CRANELIFT_BLOCK_JUMP_TRANSLATOR_NATIVE_GUARD: guard-cranelift-mir-to-cranelift-block-jump-translator-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_jump_translator_native_guard: guard-cranelift-mir-to-cranelift-block-jump-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_jump_translator_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_jump_translator_command: compiler-mir-to-cranelift-block-jump-translator-object' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_jump_translator_input_fixture: compiler/fixtures/native_backend_block_jump_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_jump_translator_oracle_guard: guard-mir-to-c-block-jump-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_jump_translator_translation_entry: translate_compiler_mir_block_jump_fixture_to_tiny_mir_block_function' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_jump_translator_object_artifact: build/guards/cranelift_mir_to_cranelift_block_jump_translator_native/tiny_native_backend_mir_to_cranelift_block_jump_translator.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_jump_translator_symbol: tiny_native_backend_mir_to_cranelift_block_jump_translator' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_jump_translator_seam_status: phase9b_translator_seed_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_jump.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_count: 2' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_terminator: Jump' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_target: return' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: Return' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_return_value: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-to-cranelift-block-jump-translator-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'translate_compiler_mir_block_jump_fixture_to_tiny_mir_block_function' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_TO_CRANELIFT_BLOCK_JUMP_TRANSLATOR_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_mir_to_cranelift_block_jump_translator_native"
    object_file="$build_dir/tiny_native_backend_mir_to_cranelift_block_jump_translator.o"
    shim_c="$build_dir/tiny_native_backend_mir_to_cranelift_block_jump_translator_main.c"
    binary="$build_dir/tiny_native_backend_mir_to_cranelift_block_jump_translator_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-to-cranelift-block-jump-translator-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_mir_to_cranelift_block_jump_translator(void);' >> "$shim_c"
    echo 'int main(void) { return tiny_native_backend_mir_to_cranelift_block_jump_translator(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "1" ]; then
      echo "Expected MIR-to-Cranelift block-jump translator seed native smoke to exit with status 1, got $status"
      exit 1
    fi
    echo "✅ MIR-to-Cranelift block-jump translator seed native smoke passed."

guard-cranelift-mir-to-cranelift-provenance-metadata-translator-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-to-Cranelift provenance-metadata translator seed..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_provenance_metadata_ingestion.mir"
    just guard-cranelift-backend-surface
    just guard-mir-to-c-provenance-metadata-native-smoke
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_TO_CRANELIFT_PROVENANCE_METADATA_TRANSLATOR_NATIVE_GUARD: guard-cranelift-mir-to-cranelift-provenance-metadata-translator-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_provenance_metadata_translator_native_guard: guard-cranelift-mir-to-cranelift-provenance-metadata-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_provenance_metadata_translator_command: compiler-mir-to-cranelift-provenance-metadata-translator-object' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_provenance_metadata_translator_translation_entry: translate_compiler_mir_provenance_metadata_fixture_to_tiny_mir_function' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_provenance_metadata_translator_symbol: tiny_native_backend_mir_to_cranelift_provenance_metadata_translator' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_provenance_metadata_translator_metadata_policy: metadata_validated_at_fixture_boundary_preserved_through_translation' "$manifest_doc" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.provenance_metadata.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'provenance_metadata_count: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'provenance_0_kind: LocalBinding' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'statement_0_kind: LocalI32Set' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'statement_0_value: 2' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'return_local: value' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-to-cranelift-provenance-metadata-translator-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'translate_compiler_mir_provenance_metadata_fixture_to_tiny_mir_function' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_mir_to_cranelift_provenance_metadata_translator_native"
    object_file="$build_dir/tiny_native_backend_mir_to_cranelift_provenance_metadata_translator.o"
    shim_c="$build_dir/tiny_native_backend_mir_to_cranelift_provenance_metadata_translator_main.c"
    binary="$build_dir/tiny_native_backend_mir_to_cranelift_provenance_metadata_translator_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-to-cranelift-provenance-metadata-translator-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_mir_to_cranelift_provenance_metadata_translator(void);' >> "$shim_c"
    echo 'int main(void) { return tiny_native_backend_mir_to_cranelift_provenance_metadata_translator(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "2" ]; then
      echo "Expected MIR-to-Cranelift provenance-metadata translator seed native smoke to exit with status 2, got $status"
      exit 1
    fi
    echo "✅ MIR-to-Cranelift provenance-metadata translator seed native smoke passed."

guard-cranelift-mir-to-cranelift-resource-metadata-translator-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-to-Cranelift resource-metadata translator seed..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_resource_metadata_ingestion.mir"
    just guard-cranelift-backend-surface
    just guard-mir-to-c-resource-metadata-native-smoke
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_TO_CRANELIFT_RESOURCE_METADATA_TRANSLATOR_NATIVE_GUARD: guard-cranelift-mir-to-cranelift-resource-metadata-translator-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_resource_metadata_translator_native_guard: guard-cranelift-mir-to-cranelift-resource-metadata-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_resource_metadata_translator_command: compiler-mir-to-cranelift-resource-metadata-translator-object' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_resource_metadata_translator_translation_entry: translate_compiler_mir_resource_metadata_fixture_to_tiny_mir_function' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_resource_metadata_translator_symbol: tiny_native_backend_mir_to_cranelift_resource_metadata_translator' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_resource_metadata_translator_metadata_policy: metadata_validated_at_fixture_boundary_preserved_through_translation' "$manifest_doc" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.resource_metadata.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'resource_metadata_count: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'resource_0_kind: LinearResource' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'resource_0_state: Live' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'statement_0_kind: LocalI32Set' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'statement_0_value: 2' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'return_local: value' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-to-cranelift-resource-metadata-translator-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'translate_compiler_mir_resource_metadata_fixture_to_tiny_mir_function' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_mir_to_cranelift_resource_metadata_translator_native"
    object_file="$build_dir/tiny_native_backend_mir_to_cranelift_resource_metadata_translator.o"
    shim_c="$build_dir/tiny_native_backend_mir_to_cranelift_resource_metadata_translator_main.c"
    binary="$build_dir/tiny_native_backend_mir_to_cranelift_resource_metadata_translator_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-to-cranelift-resource-metadata-translator-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_mir_to_cranelift_resource_metadata_translator(void);' >> "$shim_c"
    echo 'int main(void) { return tiny_native_backend_mir_to_cranelift_resource_metadata_translator(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "2" ]; then
      echo "Expected MIR-to-Cranelift resource-metadata translator seed native smoke to exit with status 2, got $status"
      exit 1
    fi
    echo "✅ MIR-to-Cranelift resource-metadata translator seed native smoke passed."

guard-cranelift-mir-to-cranelift-native-boundary-metadata-translator-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-to-Cranelift native-boundary metadata translator seed..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_native_boundary_metadata_ingestion.mir"
    just guard-cranelift-backend-surface
    just guard-mir-to-c-native-boundary-metadata-native-smoke
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_TO_CRANELIFT_NATIVE_BOUNDARY_METADATA_TRANSLATOR_NATIVE_GUARD: guard-cranelift-mir-to-cranelift-native-boundary-metadata-translator-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_native_boundary_metadata_translator_native_guard: guard-cranelift-mir-to-cranelift-native-boundary-metadata-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_native_boundary_metadata_translator_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_native_boundary_metadata_translator_command: compiler-mir-to-cranelift-native-boundary-metadata-translator-object' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_native_boundary_metadata_translator_input_fixture: compiler/fixtures/native_backend_native_boundary_metadata_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_native_boundary_metadata_translator_oracle_guard: guard-mir-to-c-native-boundary-metadata-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_native_boundary_metadata_translator_translation_entry: translate_compiler_mir_native_boundary_metadata_fixture_to_tiny_mir_function' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_native_boundary_metadata_translator_object_artifact: build/guards/cranelift_mir_to_cranelift_native_boundary_metadata_translator_native/tiny_native_backend_mir_to_cranelift_native_boundary_metadata_translator.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_native_boundary_metadata_translator_symbol: tiny_native_backend_mir_to_cranelift_native_boundary_metadata_translator' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_native_boundary_metadata_translator_expected_status: 0' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_native_boundary_metadata_translator_metadata_policy: metadata_validated_at_fixture_boundary_preserved_through_translation' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_native_boundary_metadata_translator_seam_status: phase9b_translator_seed_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.native_boundary_metadata.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'return_type: void' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'terminator: ReturnVoid' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'native_boundary_metadata_count: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'native_boundary_0_kind: RuntimeCall' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'native_boundary_0_symbol: tiny_runtime_boundary' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-to-cranelift-native-boundary-metadata-translator-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'translate_compiler_mir_native_boundary_metadata_fixture_to_tiny_mir_function' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_TO_CRANELIFT_NATIVE_BOUNDARY_METADATA_TRANSLATOR_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_mir_to_cranelift_native_boundary_metadata_translator_native"
    object_file="$build_dir/tiny_native_backend_mir_to_cranelift_native_boundary_metadata_translator.o"
    shim_c="$build_dir/tiny_native_backend_mir_to_cranelift_native_boundary_metadata_translator_main.c"
    binary="$build_dir/tiny_native_backend_mir_to_cranelift_native_boundary_metadata_translator_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-to-cranelift-native-boundary-metadata-translator-object "$fixture" "$object_file"
    test -s "$object_file"
    echo 'void tiny_native_backend_mir_to_cranelift_native_boundary_metadata_translator(void);' > "$shim_c"
    echo 'int main(void) { tiny_native_backend_mir_to_cranelift_native_boundary_metadata_translator(); return 0; }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ MIR-to-Cranelift native-boundary metadata translator seed native smoke passed."

guard-cranelift-mir-to-cranelift-add-i32-translator-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-to-Cranelift add-i32 translator seed..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_add_i32_ingestion.mir"
    just guard-cranelift-backend-surface
    just guard-cranelift-compiler-mir-add-i32-ingestion-native-smoke
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_TO_CRANELIFT_ADD_I32_TRANSLATOR_NATIVE_GUARD: guard-cranelift-mir-to-cranelift-add-i32-translator-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_add_i32_translator_native_guard: guard-cranelift-mir-to-cranelift-add-i32-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_add_i32_translator_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_add_i32_translator_command: compiler-mir-to-cranelift-add-i32-translator-object' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_add_i32_translator_input_fixture: compiler/fixtures/native_backend_add_i32_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_add_i32_translator_oracle_guard: guard-cranelift-compiler-mir-add-i32-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_add_i32_translator_translation_entry: translate_compiler_mir_add_i32_fixture_to_tiny_mir_function' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_add_i32_translator_object_artifact: build/guards/cranelift_mir_to_cranelift_add_i32_translator_native/tiny_native_backend_mir_to_cranelift_add_i32_translator.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_add_i32_translator_symbol: tiny_native_backend_mir_to_cranelift_add_i32_translator' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_add_i32_translator_expected_case_count: 2' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_add_i32_translator_expected_status: 0' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_add_i32_translator_seam_status: phase9b_translator_seed_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.add_i32.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'terminator: ReturnParamAdd' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'lhs_param: 0' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'rhs_param: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_0_lhs: 2' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_0_rhs: 3' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_0_result: 5' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_1_lhs: 0' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_1_rhs: 4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_1_result: 4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-to-cranelift-add-i32-translator-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'translate_compiler_mir_add_i32_fixture_to_tiny_mir_function' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_TO_CRANELIFT_ADD_I32_TRANSLATOR_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_mir_to_cranelift_add_i32_translator_native"
    object_file="$build_dir/tiny_native_backend_mir_to_cranelift_add_i32_translator.o"
    shim_c="$build_dir/tiny_native_backend_mir_to_cranelift_add_i32_translator_main.c"
    binary="$build_dir/tiny_native_backend_mir_to_cranelift_add_i32_translator_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-to-cranelift-add-i32-translator-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_mir_to_cranelift_add_i32_translator(int32_t lhs, int32_t rhs);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_add_i32_translator(2, 3) != 5) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_add_i32_translator(0, 4) != 4) return 2;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ MIR-to-Cranelift add-i32 translator seed native smoke passed."

guard-cranelift-mir-to-cranelift-positive-i32-branch-translator-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-to-Cranelift positive-i32 branch translator seed..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_positive_i32_branch_ingestion.mir"
    source_fixture="compiler/mir_feature_positive_i32_branch_preservation_source.gst"
    just guard-cranelift-backend-surface
    just guard-cranelift-compiler-mir-positive-i32-branch-ingestion-native-smoke
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_TO_CRANELIFT_POSITIVE_I32_BRANCH_TRANSLATOR_NATIVE_GUARD: guard-cranelift-mir-to-cranelift-positive-i32-branch-translator-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_positive_i32_branch_translator_native_guard: guard-cranelift-mir-to-cranelift-positive-i32-branch-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_positive_i32_branch_translator_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_positive_i32_branch_translator_command: compiler-mir-to-cranelift-positive-i32-branch-translator-object' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_positive_i32_branch_translator_input_fixture: compiler/fixtures/native_backend_positive_i32_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_positive_i32_branch_translator_oracle_guard: guard-cranelift-compiler-mir-positive-i32-branch-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_positive_i32_branch_translator_translation_entry: translate_compiler_mir_positive_i32_branch_fixture_to_tiny_mir_function' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_positive_i32_branch_translator_object_artifact: build/guards/cranelift_mir_to_cranelift_positive_i32_branch_translator_native/tiny_native_backend_mir_to_cranelift_positive_i32_branch_translator.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_positive_i32_branch_translator_symbol: tiny_native_backend_mir_to_cranelift_positive_i32_branch_translator' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_positive_i32_branch_translator_expected_case_count: 3' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_positive_i32_branch_translator_expected_status: 0' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_positive_i32_branch_translator_seam_status: phase9b_translator_seed_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.positive_i32_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'source_fixture: compiler/mir_feature_positive_i32_branch_preservation_source.gst' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_condition: greater_than_zero' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_param: 0' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_return_value: 7' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_return_value: 9' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_0_value: 3' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_0_result: 7' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_1_value: 0' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_1_result: 9' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_2_value: -4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_2_result: 9' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_positive_i32_branch(value: int) int' "$source_fixture" >/dev/null
    rg -n -F 'if value > 0' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-to-cranelift-positive-i32-branch-translator-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'translate_compiler_mir_positive_i32_branch_fixture_to_tiny_mir_function' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_TO_CRANELIFT_POSITIVE_I32_BRANCH_TRANSLATOR_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirTerminator::BranchParamI32Positive' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_mir_to_cranelift_positive_i32_branch_translator_native"
    object_file="$build_dir/tiny_native_backend_mir_to_cranelift_positive_i32_branch_translator.o"
    shim_c="$build_dir/tiny_native_backend_mir_to_cranelift_positive_i32_branch_translator_main.c"
    binary="$build_dir/tiny_native_backend_mir_to_cranelift_positive_i32_branch_translator_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-to-cranelift-positive-i32-branch-translator-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_mir_to_cranelift_positive_i32_branch_translator(int32_t value);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_positive_i32_branch_translator(3) != 7) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_positive_i32_branch_translator(0) != 9) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_positive_i32_branch_translator(-4) != 9) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ MIR-to-Cranelift positive-i32 branch translator seed native smoke passed."

guard-cranelift-mir-to-cranelift-block-local-branch-join-translator-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-to-Cranelift block-local branch-join translator seed..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_local_branch_join_ingestion.mir"
    source_fixture="compiler/mir_feature_block_local_branch_join_preservation_source.gst"
    just guard-cranelift-backend-surface
    just guard-cranelift-compiler-mir-block-local-branch-join-ingestion-native-smoke
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_TO_CRANELIFT_BLOCK_LOCAL_BRANCH_JOIN_TRANSLATOR_NATIVE_GUARD: guard-cranelift-mir-to-cranelift-block-local-branch-join-translator-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_local_branch_join_translator_native_guard: guard-cranelift-mir-to-cranelift-block-local-branch-join-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_local_branch_join_translator_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_local_branch_join_translator_command: compiler-mir-to-cranelift-block-local-branch-join-translator-object' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_local_branch_join_translator_input_fixture: compiler/fixtures/native_backend_block_local_branch_join_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_local_branch_join_translator_oracle_guard: guard-cranelift-compiler-mir-block-local-branch-join-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_local_branch_join_translator_translation_entry: translate_compiler_mir_block_local_branch_join_fixture_to_tiny_mir_block_function' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_local_branch_join_translator_object_artifact: build/guards/cranelift_mir_to_cranelift_block_local_branch_join_translator_native/tiny_native_backend_mir_to_cranelift_block_local_branch_join_translator.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_local_branch_join_translator_symbol: tiny_native_backend_mir_to_cranelift_block_local_branch_join_translator' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_local_branch_join_translator_expected_case_count: 3' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_local_branch_join_translator_expected_status: 0' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_local_branch_join_translator_seam_status: phase9b_translator_seed_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_local_branch_join.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'source_fixture: compiler/mir_feature_block_local_branch_join_preservation_source.gst' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_statement_0_kind: LocalI32SetParam' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_terminator: BranchLocalPositive' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_branch_local: value' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_then_block: positive' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_else_block: non_positive' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_statement_0_value: 4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_statement_0_value: 8' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_return_local: value' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_0_value: 5' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_0_result: 9' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_1_value: 0' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_1_result: 8' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_2_value: -3' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_2_result: 5' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_local_branch_join(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-to-cranelift-block-local-branch-join-translator-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'translate_compiler_mir_block_local_branch_join_fixture_to_tiny_mir_block_function' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_TO_CRANELIFT_BLOCK_LOCAL_BRANCH_JOIN_TRANSLATOR_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirBlockTerminator::BranchLocalI32Positive' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirBlockTerminator::Jump { target: "join" }' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirBlockTerminator::ReturnLocalI32("value")' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_mir_to_cranelift_block_local_branch_join_translator_native"
    object_file="$build_dir/tiny_native_backend_mir_to_cranelift_block_local_branch_join_translator.o"
    shim_c="$build_dir/tiny_native_backend_mir_to_cranelift_block_local_branch_join_translator_main.c"
    binary="$build_dir/tiny_native_backend_mir_to_cranelift_block_local_branch_join_translator_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-to-cranelift-block-local-branch-join-translator-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_mir_to_cranelift_block_local_branch_join_translator(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_block_local_branch_join_translator(5) != 9) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_block_local_branch_join_translator(0) != 8) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_block_local_branch_join_translator(-3) != 5) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ MIR-to-Cranelift block-local branch-join translator seed native smoke passed."

guard-cranelift-mir-to-cranelift-block-param-update-branch-translator-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-to-Cranelift block-param update-branch translator seed..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_update_branch_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_update_branch_preservation_source.gst"
    just guard-cranelift-backend-surface
    just guard-cranelift-compiler-mir-block-param-update-branch-ingestion-native-smoke
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_TO_CRANELIFT_BLOCK_PARAM_UPDATE_BRANCH_TRANSLATOR_NATIVE_GUARD: guard-cranelift-mir-to-cranelift-block-param-update-branch-translator-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_update_branch_translator_native_guard: guard-cranelift-mir-to-cranelift-block-param-update-branch-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_update_branch_translator_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_update_branch_translator_command: compiler-mir-to-cranelift-block-param-update-branch-translator-object' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_update_branch_translator_input_fixture: compiler/fixtures/native_backend_block_param_update_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_update_branch_translator_oracle_guard: guard-cranelift-compiler-mir-block-param-update-branch-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_update_branch_translator_translation_entry: translate_compiler_mir_block_param_update_branch_fixture_to_tiny_mir_param_block_function' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_update_branch_translator_object_artifact: build/guards/cranelift_mir_to_cranelift_block_param_update_branch_translator_native/tiny_native_backend_mir_to_cranelift_block_param_update_branch_translator.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_update_branch_translator_symbol: tiny_native_backend_mir_to_cranelift_block_param_update_branch_translator' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_update_branch_translator_expected_case_count: 3' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_update_branch_translator_expected_status: 0' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_update_branch_translator_seam_status: phase9b_translator_seed_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_update_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'source_fixture: compiler/mir_feature_block_param_update_branch_preservation_source.gst' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_terminator: JumpFunctionParam' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_target: increment' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamAddI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_add_value: 4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: BranchBlockParamPositive' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_branch_param: 0' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_return_value: 67' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_4_return_value: 71' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_0_value: 5' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_0_result: 67' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_1_value: 0' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_1_result: 67' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_2_value: -4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_2_result: 71' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_param_update_branch(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut adjusted := input + 4;' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-to-cranelift-block-param-update-branch-translator-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'translate_compiler_mir_block_param_update_branch_fixture_to_tiny_mir_param_block_function' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_UPDATE_BRANCH_TRANSLATOR_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::JumpFunctionParamI32' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::BranchBlockParamI32Positive' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_mir_to_cranelift_block_param_update_branch_translator_native"
    object_file="$build_dir/tiny_native_backend_mir_to_cranelift_block_param_update_branch_translator.o"
    shim_c="$build_dir/tiny_native_backend_mir_to_cranelift_block_param_update_branch_translator_main.c"
    binary="$build_dir/tiny_native_backend_mir_to_cranelift_block_param_update_branch_translator_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-to-cranelift-block-param-update-branch-translator-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_mir_to_cranelift_block_param_update_branch_translator(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_block_param_update_branch_translator(5) != 67) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_block_param_update_branch_translator(0) != 67) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_block_param_update_branch_translator(-4) != 71) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ MIR-to-Cranelift block-param update-branch translator seed native smoke passed."

guard-cranelift-mir-to-cranelift-block-param-merge-update-branch-translator-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-to-Cranelift block-param merge update-branch translator seed..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_merge_update_branch_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_merge_update_branch_preservation_source.gst"
    just guard-cranelift-backend-surface
    just guard-cranelift-compiler-mir-block-param-merge-update-branch-ingestion-native-smoke
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_UPDATE_BRANCH_TRANSLATOR_NATIVE_GUARD: guard-cranelift-mir-to-cranelift-block-param-merge-update-branch-translator-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_update_branch_translator_native_guard: guard-cranelift-mir-to-cranelift-block-param-merge-update-branch-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_update_branch_translator_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_update_branch_translator_command: compiler-mir-to-cranelift-block-param-merge-update-branch-translator-object' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_update_branch_translator_input_fixture: compiler/fixtures/native_backend_block_param_merge_update_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_update_branch_translator_oracle_guard: guard-cranelift-compiler-mir-block-param-merge-update-branch-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_update_branch_translator_translation_entry: translate_compiler_mir_block_param_merge_update_branch_fixture_to_tiny_mir_param_block_function' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_update_branch_translator_object_artifact: build/guards/cranelift_mir_to_cranelift_block_param_merge_update_branch_translator_native/tiny_native_backend_mir_to_cranelift_block_param_merge_update_branch_translator.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_update_branch_translator_symbol: tiny_native_backend_mir_to_cranelift_block_param_merge_update_branch_translator' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_update_branch_translator_expected_case_count: 3' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_update_branch_translator_expected_status: 0' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_update_branch_translator_seam_status: phase9b_translator_seed_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_update_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'source_fixture: compiler/mir_feature_block_param_merge_update_branch_preservation_source.gst' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamAddI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_add_value: 4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: BranchBlockParamPositiveToI32Literals' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_then_value: 181' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_else_value: 191' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_target: join' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_4_target: join' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_terminator: ReturnBlockParam' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_return_param: 0' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_0_value: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_0_result: 181' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_1_value: -4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_1_result: 191' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_2_value: -9' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_2_result: 191' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_param_merge_update_branch(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut adjusted := input + 4;' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-to-cranelift-block-param-merge-update-branch-translator-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'translate_compiler_mir_block_param_merge_update_branch_fixture_to_tiny_mir_param_block_function' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_UPDATE_BRANCH_TRANSLATOR_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::ReturnBlockParamI32(0)' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_mir_to_cranelift_block_param_merge_update_branch_translator_native"
    object_file="$build_dir/tiny_native_backend_mir_to_cranelift_block_param_merge_update_branch_translator.o"
    shim_c="$build_dir/tiny_native_backend_mir_to_cranelift_block_param_merge_update_branch_translator_main.c"
    binary="$build_dir/tiny_native_backend_mir_to_cranelift_block_param_merge_update_branch_translator_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-to-cranelift-block-param-merge-update-branch-translator-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_mir_to_cranelift_block_param_merge_update_branch_translator(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_block_param_merge_update_branch_translator(1) != 181) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_block_param_merge_update_branch_translator(-4) != 191) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_block_param_merge_update_branch_translator(-9) != 191) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ MIR-to-Cranelift block-param merge update-branch translator seed native smoke passed."

guard-cranelift-mir-to-cranelift-block-param-merge-imported-call-return-translator-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-to-Cranelift block-param merge imported-call return translator seed..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_merge_imported_call_return_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_merge_imported_call_return_preservation_source.gst"
    just guard-cranelift-backend-surface
    just guard-cranelift-compiler-mir-block-param-merge-imported-call-return-ingestion-native-smoke
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_TRANSLATOR_NATIVE_GUARD: guard-cranelift-mir-to-cranelift-block-param-merge-imported-call-return-translator-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_imported_call_return_translator_native_guard: guard-cranelift-mir-to-cranelift-block-param-merge-imported-call-return-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_imported_call_return_translator_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_imported_call_return_translator_command: compiler-mir-to-cranelift-block-param-merge-imported-call-return-translator-object' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_imported_call_return_translator_input_fixture: compiler/fixtures/native_backend_block_param_merge_imported_call_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_imported_call_return_translator_oracle_guard: guard-cranelift-compiler-mir-block-param-merge-imported-call-return-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_imported_call_return_translator_translation_entry: translate_compiler_mir_block_param_merge_imported_call_return_fixture_to_tiny_mir_param_block_function' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_imported_call_return_translator_object_artifact: build/guards/cranelift_mir_to_cranelift_block_param_merge_imported_call_return_translator_native/tiny_native_backend_mir_to_cranelift_block_param_merge_imported_call_return_translator.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_imported_call_return_translator_symbol: tiny_native_backend_mir_to_cranelift_block_param_merge_imported_call_return_translator' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_imported_call_return_translator_imported_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return_host_add' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_imported_call_return_translator_expected_case_count: 3' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_imported_call_return_translator_expected_status: 0' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_imported_call_return_translator_seam_status: phase9b_translator_seed_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_imported_call_return.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return_host_add' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'imported_function_0_operation: HostAddI32' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamAddI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_add_value: 4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: BranchBlockParamPositiveToI32Literals' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_then_value: 211' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_else_value: 223' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_target: join' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_4_target: join' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_terminator: ReturnBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_call_literal: 5' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_0_value: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_0_result: 216' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_1_value: -4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_1_result: 228' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_2_value: -9' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_2_result: 228' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_param_merge_imported_call_return(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut adjusted := input + 4;' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-to-cranelift-block-param-merge-imported-call-return-translator-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'translate_compiler_mir_block_param_merge_imported_call_return_fixture_to_tiny_mir_param_block_function' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_TRANSLATOR_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'Linkage::Import' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_mir_to_cranelift_block_param_merge_imported_call_return_translator_native"
    object_file="$build_dir/tiny_native_backend_mir_to_cranelift_block_param_merge_imported_call_return_translator.o"
    shim_c="$build_dir/tiny_native_backend_mir_to_cranelift_block_param_merge_imported_call_return_translator_main.c"
    binary="$build_dir/tiny_native_backend_mir_to_cranelift_block_param_merge_imported_call_return_translator_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-to-cranelift-block-param-merge-imported-call-return-translator-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_mir_to_cranelift_block_param_merge_imported_call_return_translator(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_block_param_merge_imported_call_return_translator(1) != 216) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_block_param_merge_imported_call_return_translator(-4) != 228) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_block_param_merge_imported_call_return_translator(-9) != 228) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ MIR-to-Cranelift block-param merge imported-call return translator seed native smoke passed."

guard-cranelift-mir-to-cranelift-block-param-merge-arm-update-imported-call-return-translator-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling MIR-to-Cranelift block-param merge arm-update imported-call return translator seed..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_return_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_merge_arm_update_imported_call_return_preservation_source.gst"
    just guard-cranelift-backend-surface
    just guard-cranelift-compiler-mir-block-param-merge-arm-update-imported-call-return-ingestion-native-smoke
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_TRANSLATOR_NATIVE_GUARD: guard-cranelift-mir-to-cranelift-block-param-merge-arm-update-imported-call-return-translator-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_native_guard: guard-cranelift-mir-to-cranelift-block-param-merge-arm-update-imported-call-return-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_command: compiler-mir-to-cranelift-block-param-merge-arm-update-imported-call-return-translator-object' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_input_fixture: compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_oracle_guard: guard-cranelift-compiler-mir-block-param-merge-arm-update-imported-call-return-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_translation_entry: translate_compiler_mir_block_param_merge_arm_update_imported_call_return_fixture_to_tiny_mir_param_block_function' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_object_artifact: build/guards/cranelift_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_native/tiny_native_backend_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_symbol: tiny_native_backend_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_imported_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return_host_add' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_expected_case_count: 3' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_expected_status: 0' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_seam_status: phase9b_translator_seed_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_arm_update_imported_call_return.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'imported_function_0_operation: HostAddI32' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: BranchBlockParamPositiveToI32Literals' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_then_value: 211' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_else_value: 223' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_add_value: 7' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_4_add_value: 9' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_terminator: ReturnBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_call_literal: 5' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_0_value: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_0_result: 223' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_1_value: -4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_1_result: 237' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_2_value: -9' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_2_result: 237' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_param_merge_arm_update_imported_call_return(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut adjusted := input + 4;' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-to-cranelift-block-param-merge-arm-update-imported-call-return-translator-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'translate_compiler_mir_block_param_merge_arm_update_imported_call_return_fixture_to_tiny_mir_param_block_function' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_TRANSLATOR_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'Linkage::Import' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_native"
    object_file="$build_dir/tiny_native_backend_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator.o"
    shim_c="$build_dir/tiny_native_backend_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_main.c"
    binary="$build_dir/tiny_native_backend_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-to-cranelift-block-param-merge-arm-update-imported-call-return-translator-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator(1) != 223) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator(-4) != 237) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator(-9) != 237) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ MIR-to-Cranelift block-param merge arm-update imported-call return translator seed native smoke passed."

guard-cranelift-mir-to-cranelift-translator-seed-suite:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Running MIR-to-Cranelift translator seed suite..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_TO_CRANELIFT_TRANSLATOR_SEED_SUITE_NATIVE_GUARD: guard-cranelift-mir-to-cranelift-translator-seed-suite' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_native_guard: guard-cranelift-mir-to-cranelift-translator-seed-suite' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_status: phase9b_translator_seed_inventory' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_count: 14' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_return_int_guard: guard-cranelift-mir-to-cranelift-return-int-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_local_binding_read_guard: guard-cranelift-mir-to-cranelift-local-binding-read-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_conditional_branch_guard: guard-cranelift-mir-to-cranelift-conditional-branch-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_block_jump_guard: guard-cranelift-mir-to-cranelift-block-jump-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_provenance_metadata_guard: guard-cranelift-mir-to-cranelift-provenance-metadata-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_resource_metadata_guard: guard-cranelift-mir-to-cranelift-resource-metadata-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_native_boundary_metadata_guard: guard-cranelift-mir-to-cranelift-native-boundary-metadata-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_add_i32_guard: guard-cranelift-mir-to-cranelift-add-i32-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_positive_i32_branch_guard: guard-cranelift-mir-to-cranelift-positive-i32-branch-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_block_local_branch_join_guard: guard-cranelift-mir-to-cranelift-block-local-branch-join-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_block_param_update_branch_guard: guard-cranelift-mir-to-cranelift-block-param-update-branch-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_block_param_merge_update_branch_guard: guard-cranelift-mir-to-cranelift-block-param-merge-update-branch-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_block_param_merge_imported_call_return_guard: guard-cranelift-mir-to-cranelift-block-param-merge-imported-call-return-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_block_param_merge_arm_update_imported_call_return_guard: guard-cranelift-mir-to-cranelift-block-param-merge-arm-update-imported-call-return-translator-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_oracle_policy: mir_to_c_or_compiler_owned_fixture_native_guards_remain_oracle' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_to_cranelift_translator_seed_suite_route_policy: experiment_only_no_production_routing' "$manifest_doc" >/dev/null
    just guard-cranelift-mir-to-cranelift-return-int-translator-native-smoke
    just guard-cranelift-mir-to-cranelift-local-binding-read-translator-native-smoke
    just guard-cranelift-mir-to-cranelift-conditional-branch-translator-native-smoke
    just guard-cranelift-mir-to-cranelift-block-jump-translator-native-smoke
    just guard-cranelift-mir-to-cranelift-provenance-metadata-translator-native-smoke
    just guard-cranelift-mir-to-cranelift-resource-metadata-translator-native-smoke
    just guard-cranelift-mir-to-cranelift-native-boundary-metadata-translator-native-smoke
    just guard-cranelift-mir-to-cranelift-add-i32-translator-native-smoke
    just guard-cranelift-mir-to-cranelift-positive-i32-branch-translator-native-smoke
    just guard-cranelift-mir-to-cranelift-block-local-branch-join-translator-native-smoke
    just guard-cranelift-mir-to-cranelift-block-param-update-branch-translator-native-smoke
    just guard-cranelift-mir-to-cranelift-block-param-merge-update-branch-translator-native-smoke
    just guard-cranelift-mir-to-cranelift-block-param-merge-imported-call-return-translator-native-smoke
    just guard-cranelift-mir-to-cranelift-block-param-merge-arm-update-imported-call-return-translator-native-smoke
    echo "✅ MIR-to-Cranelift translator seed suite passed."

guard-cranelift-compiler-mir-local-binding-read-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR local-binding/read ingestion seam smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_local_binding_read_ingestion.mir"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_LOCAL_BINDING_READ_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-local-binding-read-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_local_binding_read_ingestion_native_guard: guard-cranelift-compiler-mir-local-binding-read-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_local_binding_read_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_local_binding_read_ingestion_fixture: compiler/fixtures/native_backend_local_binding_read_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_local_binding_read_ingestion_fixture_producer: compiler/mir.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_local_binding_read_ingestion_fixture_producer_entry: mir_emit_native_backend_local_binding_read_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_local_binding_read_ingestion_object_artifact: build/guards/cranelift_compiler_mir_local_binding_read_ingestion_native/tiny_native_backend_compiler_mir_ingested_local_binding_read.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_local_binding_read_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_local_binding_read' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_local_binding_read_ingestion_source_fixture: compiler/mir_feature_local_binding_read_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_local_binding_read_ingestion_lowering_entry: mir_lower_local_binding_read_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_local_binding_read_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_local_binding_read_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'mir_lower_local_binding_read_fixture(ctx)' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.local_binding_read.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer_entry: mir_emit_native_backend_local_binding_read_ingestion_fixture' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'source_fixture: compiler/mir_feature_local_binding_read_preservation_source.gst' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'lowering_entry: mir_lower_local_binding_read_fixture' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'statement_0_kind: LocalI32Set' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'statement_0_value: 2' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'return_local: value' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_local_binding_read' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-local-binding-read-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_local_binding_read_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_LOCAL_BINDING_READ_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_local_binding_read_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_local_binding_read.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_local_binding_read_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_local_binding_read_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-local-binding-read-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_local_binding_read(void);' >> "$shim_c"
    echo 'int main(void) { return tiny_native_backend_compiler_mir_ingested_local_binding_read(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "2" ]; then
      echo "Expected compiler-owned MIR local-binding/read ingestion native smoke to exit with status 2, got $status"
      exit 1
    fi
    echo "✅ Compiler-owned MIR local-binding/read ingestion seam native smoke passed."

guard-cranelift-compiler-mir-conditional-branch-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR conditional-branch ingestion seam smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_conditional_branch_ingestion.mir"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_CONDITIONAL_BRANCH_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-conditional-branch-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_conditional_branch_ingestion_native_guard: guard-cranelift-compiler-mir-conditional-branch-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_conditional_branch_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_conditional_branch_ingestion_fixture: compiler/fixtures/native_backend_conditional_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_conditional_branch_ingestion_fixture_producer: compiler/mir.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_conditional_branch_ingestion_fixture_producer_entry: mir_emit_native_backend_conditional_branch_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_conditional_branch_ingestion_object_artifact: build/guards/cranelift_compiler_mir_conditional_branch_ingestion_native/tiny_native_backend_compiler_mir_ingested_conditional_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_conditional_branch_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_conditional_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_conditional_branch_ingestion_source_fixture: compiler/mir_feature_if_else_return_int_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_conditional_branch_ingestion_lowering_entry: mir_lower_conditional_branch_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_conditional_branch_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_conditional_branch_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'mir_lower_conditional_branch_fixture(ctx)' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.conditional_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer_entry: mir_emit_native_backend_conditional_branch_ingestion_fixture' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'source_fixture: compiler/mir_feature_if_else_return_int_preservation_source.gst' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'lowering_entry: mir_lower_conditional_branch_fixture' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_count: 3' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_terminator: Branch' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_condition_kind: IntLiteral' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_then_block: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_else_block: 2' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_return_value: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_return_value: 2' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_conditional_branch' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-conditional-branch-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_conditional_branch_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_CONDITIONAL_BRANCH_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_conditional_branch_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_conditional_branch.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_conditional_branch_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_conditional_branch_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-conditional-branch-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_conditional_branch(void);' >> "$shim_c"
    echo 'int main(void) { return tiny_native_backend_compiler_mir_ingested_conditional_branch(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "1" ]; then
      echo "Expected compiler-owned MIR conditional-branch ingestion native smoke to exit with status 1, got $status"
      exit 1
    fi
    echo "✅ Compiler-owned MIR conditional-branch ingestion seam native smoke passed."

guard-cranelift-compiler-mir-add-i32-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR add-i32 ingestion seam smoke..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_add_i32_ingestion.mir"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_ADD_I32_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-add-i32-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_add_i32_ingestion_native_guard: guard-cranelift-compiler-mir-add-i32-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_add_i32_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_add_i32_ingestion_fixture: compiler/fixtures/native_backend_add_i32_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_add_i32_ingestion_fixture_producer: compiler/mir.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_add_i32_ingestion_fixture_producer_entry: mir_emit_native_backend_add_i32_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_add_i32_ingestion_object_artifact: build/guards/cranelift_compiler_mir_add_i32_ingestion_native/tiny_native_backend_compiler_mir_ingested_add_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_add_i32_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_add_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_add_i32_ingestion_source_fixture: compiler/mir_feature_add_i32_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_add_i32_ingestion_lowering_entry: fixture_only_param_add_i32_serialization' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_add_i32_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_add_i32_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.add_i32.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer: compiler/mir.gst' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer_entry: mir_emit_native_backend_add_i32_ingestion_fixture' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'terminator: ReturnParamAdd' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'rhs_param: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_add_i32' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-add-i32-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_add_i32_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_ADD_I32_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_add_i32_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_add_i32.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_add_i32_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_add_i32_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-add-i32-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_add_i32(int32_t lhs, int32_t rhs);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_add_i32(2, 3) != 5) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_add_i32(0, 4) != 4) return 2;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR add-i32 ingestion seam native smoke passed."

guard-cranelift-compiler-mir-provenance-metadata-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR provenance metadata ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_provenance_metadata_ingestion.mir"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_PROVENANCE_METADATA_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-provenance-metadata-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_provenance_metadata_ingestion_native_guard: guard-cranelift-compiler-mir-provenance-metadata-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_provenance_metadata_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_provenance_metadata_ingestion_fixture: compiler/fixtures/native_backend_provenance_metadata_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_provenance_metadata_ingestion_fixture_producer: compiler/mir.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_provenance_metadata_ingestion_fixture_producer_entry: mir_emit_native_backend_provenance_metadata_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_provenance_metadata_ingestion_object_artifact: build/guards/cranelift_compiler_mir_provenance_metadata_ingestion_native/tiny_native_backend_compiler_mir_ingested_provenance_metadata.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_provenance_metadata_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_provenance_metadata' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_provenance_metadata_ingestion_source_fixture: compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_provenance_metadata_ingestion_lowering_entry: mir_lower_provenance_metadata_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_provenance_metadata_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_provenance_metadata_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'mir_lower_provenance_metadata_fixture(ctx)' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.provenance_metadata.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer_entry: mir_emit_native_backend_provenance_metadata_ingestion_fixture' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'provenance_metadata_count: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'provenance_0_kind: LocalBinding' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'provenance_0_origin: compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_provenance_metadata' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-provenance-metadata-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_provenance_metadata_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_PROVENANCE_METADATA_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_provenance_metadata_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_provenance_metadata.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_provenance_metadata_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_provenance_metadata_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-provenance-metadata-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_provenance_metadata(void);' >> "$shim_c"
    echo 'int main(void) { return tiny_native_backend_compiler_mir_ingested_provenance_metadata(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "2" ]; then
      echo "Expected compiler-owned MIR provenance metadata ingestion native smoke to exit with status 2, got $status"
      exit 1
    fi
    echo "✅ Compiler-owned MIR provenance metadata ingestion seam native smoke passed."

guard-cranelift-compiler-mir-resource-metadata-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR resource metadata ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_resource_metadata_ingestion.mir"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_RESOURCE_METADATA_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-resource-metadata-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_resource_metadata_ingestion_native_guard: guard-cranelift-compiler-mir-resource-metadata-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_resource_metadata_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_resource_metadata_ingestion_fixture: compiler/fixtures/native_backend_resource_metadata_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_resource_metadata_ingestion_fixture_producer: compiler/mir.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_resource_metadata_ingestion_fixture_producer_entry: mir_emit_native_backend_resource_metadata_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_resource_metadata_ingestion_object_artifact: build/guards/cranelift_compiler_mir_resource_metadata_ingestion_native/tiny_native_backend_compiler_mir_ingested_resource_metadata.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_resource_metadata_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_resource_metadata' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_resource_metadata_ingestion_source_fixture: compiler/mir_feature_local_binding_read_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_resource_metadata_ingestion_lowering_entry: mir_lower_resource_metadata_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_resource_metadata_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_resource_metadata_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'mir_lower_resource_metadata_fixture(ctx)' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.resource_metadata.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer_entry: mir_emit_native_backend_resource_metadata_ingestion_fixture' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'resource_metadata_count: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'resource_0_kind: LinearResource' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'resource_0_state: Live' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_resource_metadata' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-resource-metadata-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_resource_metadata_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_RESOURCE_METADATA_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_resource_metadata_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_resource_metadata.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_resource_metadata_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_resource_metadata_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-resource-metadata-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_resource_metadata(void);' >> "$shim_c"
    echo 'int main(void) { return tiny_native_backend_compiler_mir_ingested_resource_metadata(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "2" ]; then
      echo "Expected compiler-owned MIR resource metadata ingestion native smoke to exit with status 2, got $status"
      exit 1
    fi
    echo "✅ Compiler-owned MIR resource metadata ingestion seam native smoke passed."

guard-cranelift-compiler-mir-native-boundary-metadata-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR native-boundary metadata ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_native_boundary_metadata_ingestion.mir"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_NATIVE_BOUNDARY_METADATA_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-native-boundary-metadata-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_native_boundary_metadata_ingestion_native_guard: guard-cranelift-compiler-mir-native-boundary-metadata-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_native_boundary_metadata_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_native_boundary_metadata_ingestion_fixture: compiler/fixtures/native_backend_native_boundary_metadata_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_native_boundary_metadata_ingestion_fixture_producer: compiler/mir.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_native_boundary_metadata_ingestion_fixture_producer_entry: mir_emit_native_backend_native_boundary_metadata_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_native_boundary_metadata_ingestion_object_artifact: build/guards/cranelift_compiler_mir_native_boundary_metadata_ingestion_native/tiny_native_backend_compiler_mir_ingested_native_boundary_metadata.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_native_boundary_metadata_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_native_boundary_metadata' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_native_boundary_metadata_ingestion_source_fixture: compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_native_boundary_metadata_ingestion_lowering_entry: mir_lower_native_boundary_metadata_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_native_boundary_metadata_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_native_boundary_metadata_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'mir_lower_native_boundary_metadata_fixture(ctx)' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.native_boundary_metadata.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer_entry: mir_emit_native_backend_native_boundary_metadata_ingestion_fixture' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'return_type: void' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'terminator: ReturnVoid' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'native_boundary_metadata_count: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'native_boundary_0_kind: RuntimeCall' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_native_boundary_metadata' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-native-boundary-metadata-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_native_boundary_metadata_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_NATIVE_BOUNDARY_METADATA_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_native_boundary_metadata_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_native_boundary_metadata.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_native_boundary_metadata_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_native_boundary_metadata_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-native-boundary-metadata-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo 'void tiny_native_backend_compiler_mir_ingested_native_boundary_metadata(void);' > "$shim_c"
    echo 'int main(void) { tiny_native_backend_compiler_mir_ingested_native_boundary_metadata(); return 0; }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR native-boundary metadata ingestion seam native smoke passed."

guard-cranelift-compiler-mir-positive-i32-branch-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR positive-i32 branch ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_positive_i32_branch_ingestion.mir"
    source_fixture="compiler/mir_feature_positive_i32_branch_preservation_source.gst"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_POSITIVE_I32_BRANCH_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-positive-i32-branch-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_positive_i32_branch_ingestion_native_guard: guard-cranelift-compiler-mir-positive-i32-branch-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_positive_i32_branch_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_positive_i32_branch_ingestion_fixture: compiler/fixtures/native_backend_positive_i32_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_positive_i32_branch_ingestion_fixture_producer: compiler/mir.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_positive_i32_branch_ingestion_fixture_producer_entry: mir_emit_native_backend_positive_i32_branch_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_positive_i32_branch_ingestion_object_artifact: build/guards/cranelift_compiler_mir_positive_i32_branch_ingestion_native/tiny_native_backend_compiler_mir_ingested_positive_i32_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_positive_i32_branch_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_positive_i32_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_positive_i32_branch_ingestion_source_fixture: compiler/mir_feature_positive_i32_branch_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_positive_i32_branch_ingestion_lowering_entry: fixture_only_param_positive_i32_branch_serialization' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_positive_i32_branch_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_positive_i32_branch_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.positive_i32_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer_entry: mir_emit_native_backend_positive_i32_branch_ingestion_fixture' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'source_fixture: compiler/mir_feature_positive_i32_branch_preservation_source.gst' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_condition: greater_than_zero' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_return_value: 7' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_return_value: 9' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_2_value: -4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_positive_i32_branch(value: int) int' "$source_fixture" >/dev/null
    rg -n -F 'if value > 0' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-positive-i32-branch-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_positive_i32_branch_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_POSITIVE_I32_BRANCH_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirTerminator::BranchParamI32Positive' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_positive_i32_branch_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_positive_i32_branch.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_positive_i32_branch_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_positive_i32_branch_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-positive-i32-branch-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_positive_i32_branch(int32_t value);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_positive_i32_branch(3) != 7) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_positive_i32_branch(0) != 9) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_positive_i32_branch(-4) != 9) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR positive-i32 branch ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-jump-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-jump ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_jump_ingestion.mir"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_BLOCK_JUMP_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-block-jump-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_block_jump_ingestion_native_guard: guard-cranelift-compiler-mir-block-jump-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_jump_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_jump_ingestion_fixture: compiler/fixtures/native_backend_block_jump_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_jump_ingestion_fixture_producer: compiler/mir.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_jump_ingestion_fixture_producer_entry: mir_emit_native_backend_block_jump_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_jump_ingestion_object_artifact: build/guards/cranelift_compiler_mir_block_jump_ingestion_native/tiny_native_backend_compiler_mir_ingested_block_jump.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_jump_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_block_jump' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_jump_ingestion_source_fixture: compiler/mir_lower_block_jump_smoke_test_entry.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_jump_ingestion_lowering_entry: mir_lower_block_jump_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_jump_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_block_jump_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'mir_lower_block_jump_fixture(ctx)' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_jump.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer_entry: mir_emit_native_backend_block_jump_ingestion_fixture' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_terminator: Jump' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_target: return' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_return_value: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_jump' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-block-jump-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_block_jump_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_JUMP_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirBlockTerminator::Jump' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_jump_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_jump.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_jump_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_jump_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-jump-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_jump(void);' >> "$shim_c"
    echo 'int main(void) { return tiny_native_backend_compiler_mir_ingested_block_jump(); }' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    set +e
    "$binary"
    status="$?"
    set -e
    if [ "$status" != "1" ]; then
      echo "Expected compiler-owned MIR block-jump ingestion native smoke to exit with status 1, got $status"
      exit 1
    fi
    echo "✅ Compiler-owned MIR block-jump ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-local-branch-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-local branch ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_local_branch_ingestion.mir"
    source_fixture="compiler/mir_feature_block_local_branch_preservation_source.gst"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_BLOCK_LOCAL_BRANCH_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-block-local-branch-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_ingestion_native_guard: guard-cranelift-compiler-mir-block-local-branch-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_ingestion_fixture: compiler/fixtures/native_backend_block_local_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_ingestion_fixture_producer: compiler/mir.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_ingestion_fixture_producer_entry: mir_emit_native_backend_block_local_branch_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_ingestion_object_artifact: build/guards/cranelift_compiler_mir_block_local_branch_ingestion_native/tiny_native_backend_compiler_mir_ingested_block_local_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_block_local_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_ingestion_source_fixture: compiler/mir_feature_block_local_branch_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_ingestion_lowering_entry: fixture_only_block_local_branch_serialization' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_block_local_branch_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_local_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer_entry: mir_emit_native_backend_block_local_branch_ingestion_fixture' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_statement_0_kind: LocalI32SetParam' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_terminator: BranchLocalPositive' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_return_value: 43' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_return_value: 47' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_local_branch' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_local_branch(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut value := input;' "$source_fixture" >/dev/null
    rg -n -F 'if value > 0' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-block-local-branch-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_block_local_branch_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_LOCAL_BRANCH_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirBlockStatement::LocalI32SetParam' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirBlockTerminator::BranchLocalI32Positive' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_local_branch_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_local_branch.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_local_branch_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_local_branch_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-local-branch-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_local_branch(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_local_branch(5) != 43) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_local_branch(0) != 47) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_local_branch(-2) != 47) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-local branch ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-local-update-branch-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-local update branch ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_local_update_branch_ingestion.mir"
    source_fixture="compiler/mir_feature_block_local_update_branch_preservation_source.gst"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_BLOCK_LOCAL_UPDATE_BRANCH_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-block-local-update-branch-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_update_branch_ingestion_native_guard: guard-cranelift-compiler-mir-block-local-update-branch-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_update_branch_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_update_branch_ingestion_fixture: compiler/fixtures/native_backend_block_local_update_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_update_branch_ingestion_fixture_producer: compiler/mir.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_update_branch_ingestion_fixture_producer_entry: mir_emit_native_backend_block_local_update_branch_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_update_branch_ingestion_object_artifact: build/guards/cranelift_compiler_mir_block_local_update_branch_ingestion_native/tiny_native_backend_compiler_mir_ingested_block_local_update_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_update_branch_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_block_local_update_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_update_branch_ingestion_source_fixture: compiler/mir_feature_block_local_update_branch_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_update_branch_ingestion_lowering_entry: fixture_only_block_local_update_branch_serialization' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_update_branch_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_block_local_update_branch_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_local_update_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer_entry: mir_emit_native_backend_block_local_update_branch_ingestion_fixture' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_statement_0_kind: LocalI32SetParam' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_statement_0_kind: LocalI32AddI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_statement_0_value: 2' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: BranchLocalPositive' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_return_value: 53' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_return_value: 59' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_local_update_branch' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_local_update_branch(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut value := input + 2;' "$source_fixture" >/dev/null
    rg -n -F 'if value > 0' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-block-local-update-branch-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_block_local_update_branch_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_LOCAL_UPDATE_BRANCH_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirBlockStatement::LocalI32AddI32Literal' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirBlockTerminator::BranchLocalI32Positive' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_local_update_branch_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_local_update_branch.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_local_update_branch_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_local_update_branch_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-local-update-branch-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_local_update_branch(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_local_update_branch(5) != 53) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_local_update_branch(0) != 53) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_local_update_branch(-3) != 59) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-local update branch ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-two-local-update-branch-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block two-local update branch ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_two_local_update_branch_ingestion.mir"
    source_fixture="compiler/mir_feature_block_two_local_update_branch_preservation_source.gst"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_BLOCK_TWO_LOCAL_UPDATE_BRANCH_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-block-two-local-update-branch-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_block_two_local_update_branch_ingestion_native_guard: guard-cranelift-compiler-mir-block-two-local-update-branch-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_two_local_update_branch_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_two_local_update_branch_ingestion_fixture: compiler/fixtures/native_backend_block_two_local_update_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_two_local_update_branch_ingestion_fixture_producer: compiler/mir.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_two_local_update_branch_ingestion_fixture_producer_entry: mir_emit_native_backend_block_two_local_update_branch_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_two_local_update_branch_ingestion_object_artifact: build/guards/cranelift_compiler_mir_block_two_local_update_branch_ingestion_native/tiny_native_backend_compiler_mir_ingested_block_two_local_update_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_two_local_update_branch_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_block_two_local_update_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_two_local_update_branch_ingestion_source_fixture: compiler/mir_feature_block_two_local_update_branch_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_two_local_update_branch_ingestion_lowering_entry: fixture_only_block_two_local_update_branch_serialization' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_two_local_update_branch_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_block_two_local_update_branch_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_two_local_update_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer_entry: mir_emit_native_backend_block_two_local_update_branch_ingestion_fixture' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'local_count: 2' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_statement_0_local: raw' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_statement_1_local: adjusted' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_statement_0_kind: LocalI32AddI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_statement_0_local: adjusted' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_statement_0_value: 3' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: BranchLocalPositive' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_branch_local: adjusted' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_return_value: 61' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_return_value: 67' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_two_local_update_branch' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_two_local_update_branch(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut raw := input;' "$source_fixture" >/dev/null
    rg -n -F 'mut adjusted := raw + 3;' "$source_fixture" >/dev/null
    rg -n -F 'if adjusted > 0' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-block-two-local-update-branch-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_block_two_local_update_branch_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_TWO_LOCAL_UPDATE_BRANCH_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_BLOCK_TWO_LOCAL_UPDATE_BRANCH_LOCALS: [TinyMirLocal; 2]' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirBlockStatement::LocalI32SetParam' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirBlockStatement::LocalI32AddI32Literal' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirBlockTerminator::BranchLocalI32Positive' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_two_local_update_branch_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_two_local_update_branch.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_two_local_update_branch_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_two_local_update_branch_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-two-local-update-branch-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_two_local_update_branch(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_two_local_update_branch(5) != 61) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_two_local_update_branch(-2) != 61) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_two_local_update_branch(-3) != 67) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block two-local update branch ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-local-branch-join-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-local branch join ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_local_branch_join_ingestion.mir"
    source_fixture="compiler/mir_feature_block_local_branch_join_preservation_source.gst"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_BLOCK_LOCAL_BRANCH_JOIN_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-block-local-branch-join-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_join_ingestion_native_guard: guard-cranelift-compiler-mir-block-local-branch-join-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_join_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_join_ingestion_fixture: compiler/fixtures/native_backend_block_local_branch_join_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_join_ingestion_fixture_producer: compiler/mir.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_join_ingestion_fixture_producer_entry: mir_emit_native_backend_block_local_branch_join_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_join_ingestion_object_artifact: build/guards/cranelift_compiler_mir_block_local_branch_join_ingestion_native/tiny_native_backend_compiler_mir_ingested_block_local_branch_join.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_join_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_block_local_branch_join' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_join_ingestion_source_fixture: compiler/mir_feature_block_local_branch_join_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_join_ingestion_lowering_entry: fixture_only_block_local_branch_join_serialization' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_local_branch_join_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_block_local_branch_join_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_local_branch_join.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'producer_entry: mir_emit_native_backend_block_local_branch_join_ingestion_fixture' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_terminator: BranchLocalPositive' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_statement_0_value: 4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_target: join' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_statement_0_value: 8' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_target: join' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_return_value_kind: LocalRead' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_return_local: value' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'backend_symbol: tiny_native_backend_compiler_mir_ingested_block_local_branch_join' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_local_branch_join(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'value = value + 4;' "$source_fixture" >/dev/null
    rg -n -F 'value = value + 8;' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-block-local-branch-join-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_block_local_branch_join_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_LOCAL_BRANCH_JOIN_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirBlockTerminator::ReturnLocalI32("value")' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirBlockTerminator::BranchLocalI32Positive' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirBlockTerminator::Jump { target: "join" }' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_local_branch_join_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_local_branch_join.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_local_branch_join_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_local_branch_join_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-local-branch-join-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_local_branch_join(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_local_branch_join(5) != 9) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_local_branch_join(0) != 8) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_local_branch_join(-3) != 5) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-local branch join ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-update-branch-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param update branch ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_update_branch_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_update_branch_preservation_source.gst"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_BLOCK_PARAM_UPDATE_BRANCH_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-block-param-update-branch-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_update_branch_ingestion_native_guard: guard-cranelift-compiler-mir-block-param-update-branch-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_update_branch_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_update_branch_ingestion_fixture: compiler/fixtures/native_backend_block_param_update_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_update_branch_ingestion_fixture_producer_entry: mir_emit_native_backend_block_param_update_branch_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_update_branch_ingestion_object_artifact: build/guards/cranelift_compiler_mir_block_param_update_branch_ingestion_native/tiny_native_backend_compiler_mir_ingested_block_param_update_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_update_branch_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_block_param_update_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_update_branch_ingestion_source_fixture: compiler/mir_feature_block_param_update_branch_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_update_branch_ingestion_lowering_entry: fixture_only_block_param_update_branch_serialization' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_update_branch_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_block_param_update_branch_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_update_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_terminator: JumpFunctionParam' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamAddI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_add_value: 4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: BranchBlockParamPositive' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_return_value: 67' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_4_return_value: 71' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_param_update_branch(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut adjusted := input + 4;' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-block-param-update-branch-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_block_param_update_branch_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_UPDATE_BRANCH_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::JumpFunctionParamI32' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::BranchBlockParamI32Positive' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_update_branch_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_update_branch.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_update_branch_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_update_branch_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-update-branch-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_update_branch(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_update_branch(5) != 67) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_update_branch(0) != 67) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_update_branch(-4) != 71) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param update branch ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-local-call-branch-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param local-call branch ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_local_call_branch_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_local_call_branch_preservation_source.gst"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_BLOCK_PARAM_LOCAL_CALL_BRANCH_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-block-param-local-call-branch-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_local_call_branch_ingestion_native_guard: guard-cranelift-compiler-mir-block-param-local-call-branch-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_local_call_branch_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_local_call_branch_ingestion_fixture: compiler/fixtures/native_backend_block_param_local_call_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_local_call_branch_ingestion_fixture_producer_entry: mir_emit_native_backend_block_param_local_call_branch_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_local_call_branch_ingestion_object_artifact: build/guards/cranelift_compiler_mir_block_param_local_call_branch_ingestion_native/tiny_native_backend_compiler_mir_ingested_block_param_local_call_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_local_call_branch_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_call_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_local_call_branch_ingestion_helper_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_call_helper' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_local_call_branch_ingestion_source_fixture: compiler/mir_feature_block_param_local_call_branch_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_local_call_branch_ingestion_lowering_entry: fixture_only_block_param_local_call_branch_serialization' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_local_call_branch_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_block_param_local_call_branch_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_local_call_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'local_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_call_helper' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'local_function_0_operation: AddI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'local_function_0_add_value: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_terminator: JumpFunctionParam' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: BranchBlockParamLocalFunctionPositive' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_local_function_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_call_helper' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_return_value: 79' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_return_value: 83' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_param_local_call_branch(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut called := input + 1;' "$source_fixture" >/dev/null
    rg -n -F 'if called > 0' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-block-param-local-call-branch-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_block_param_local_call_branch_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_CALL_BRANCH_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_CALL_HELPER_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirTerminator::ReturnParamI32AddLiteral { param: 0, value: 1 }' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::BranchBlockParamLocalFunctionI32CallPositive' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_local_call_branch_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_local_call_branch.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_local_call_branch_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_local_call_branch_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-local-call-branch-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_local_call_branch(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_local_call_branch(5) != 79) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_local_call_branch(0) != 79) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_local_call_branch(-1) != 83) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param local-call branch ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-imported-call-branch-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param imported-call branch ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_imported_call_branch_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_imported_call_branch_preservation_source.gst"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_BLOCK_PARAM_IMPORTED_CALL_BRANCH_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-block-param-imported-call-branch-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_branch_ingestion_native_guard: guard-cranelift-compiler-mir-block-param-imported-call-branch-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_branch_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_branch_ingestion_fixture: compiler/fixtures/native_backend_block_param_imported_call_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_branch_ingestion_fixture_producer_entry: mir_emit_native_backend_block_param_imported_call_branch_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_branch_ingestion_object_artifact: build/guards/cranelift_compiler_mir_block_param_imported_call_branch_ingestion_native/tiny_native_backend_compiler_mir_ingested_block_param_imported_call_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_branch_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_call_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_branch_ingestion_imported_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_call_host_add' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_branch_ingestion_source_fixture: compiler/mir_feature_block_param_imported_call_branch_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_branch_ingestion_lowering_entry: fixture_only_block_param_imported_call_branch_serialization' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_branch_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_block_param_imported_call_branch_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_imported_call_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_call_host_add' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'imported_function_0_operation: HostAddI32' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_terminator: JumpFunctionParam' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: BranchBlockParamImportedFunctionCallI32LiteralPositive' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_call_literal: -3' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_return_value: 89' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_return_value: 97' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_param_imported_call_branch(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut called := input - 3;' "$source_fixture" >/dev/null
    rg -n -F 'if called > 0' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-block-param-imported-call-branch-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_block_param_imported_call_branch_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_BRANCH_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_HOST_ADD_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallI32LiteralPositive' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'Linkage::Import' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_imported_call_branch_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_imported_call_branch.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_imported_call_branch_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_imported_call_branch_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-imported-call-branch-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_imported_call_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_imported_call_branch(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_imported_call_branch(5) != 89) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_imported_call_branch(3) != 97) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_imported_call_branch(-2) != 97) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param imported-call branch ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-imported-call-return-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param imported-call return ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_imported_call_return_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_imported_call_return_preservation_source.gst"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_BLOCK_PARAM_IMPORTED_CALL_RETURN_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-block-param-imported-call-return-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_return_ingestion_native_guard: guard-cranelift-compiler-mir-block-param-imported-call-return-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_return_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_return_ingestion_fixture: compiler/fixtures/native_backend_block_param_imported_call_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_return_ingestion_fixture_producer_entry: mir_emit_native_backend_block_param_imported_call_return_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_return_ingestion_object_artifact: build/guards/cranelift_compiler_mir_block_param_imported_call_return_ingestion_native/tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_return_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_return_ingestion_imported_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return_host_add' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_return_ingestion_source_fixture: compiler/mir_feature_block_param_imported_call_return_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_return_ingestion_lowering_entry: fixture_only_block_param_imported_call_return_serialization' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_call_return_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_block_param_imported_call_return_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_imported_call_return.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return_host_add' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'imported_function_0_operation: HostAddI32' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_0_terminator: JumpFunctionParam' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: ReturnBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_call_literal: 11' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_0_result: 16' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_1_result: 11' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'expected_case_2_result: -1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_param_imported_call_return(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut called := input + 11;' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-block-param-imported-call-return-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_block_param_imported_call_return_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_RETURN_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'Linkage::Import' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_imported_call_return_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-imported-call-return-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return(5) != 16) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return(0) != 11) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return(-12) != -1) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param imported-call return ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-imported-predicate-update-branch-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param imported-predicate update branch ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_imported_predicate_update_branch_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_imported_predicate_update_branch_preservation_source.gst"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_BLOCK_PARAM_IMPORTED_PREDICATE_UPDATE_BRANCH_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-block-param-imported-predicate-update-branch-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_predicate_update_branch_ingestion_native_guard: guard-cranelift-compiler-mir-block-param-imported-predicate-update-branch-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_predicate_update_branch_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_predicate_update_branch_ingestion_fixture: compiler/fixtures/native_backend_block_param_imported_predicate_update_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_predicate_update_branch_ingestion_fixture_producer_entry: mir_emit_native_backend_block_param_imported_predicate_update_branch_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_predicate_update_branch_ingestion_object_artifact: build/guards/cranelift_compiler_mir_block_param_imported_predicate_update_branch_ingestion_native/tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_update_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_predicate_update_branch_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_update_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_predicate_update_branch_ingestion_imported_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_host_is_positive' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_predicate_update_branch_ingestion_source_fixture: compiler/mir_feature_block_param_imported_predicate_update_branch_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_predicate_update_branch_ingestion_lowering_entry: fixture_only_block_param_imported_predicate_update_branch_serialization' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_imported_predicate_update_branch_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_block_param_imported_predicate_update_branch_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_imported_predicate_update_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_host_is_positive' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'imported_function_0_operation: HostIsPositiveI32' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamAddI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_add_value: -4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: BranchBlockParamImportedFunctionPredicate' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_condition: imported_predicate_nonzero' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_return_value: 101' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_4_return_value: 107' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_param_imported_predicate_update_branch(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut predicated := input - 4;' "$source_fixture" >/dev/null
    rg -n -F 'if predicated > 0' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-block-param-imported-predicate-update-branch-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_block_param_imported_predicate_update_branch_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_PREDICATE_UPDATE_BRANCH_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_PREDICATE_HOST_IS_POSITIVE_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32Predicate' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'Linkage::Import' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_imported_predicate_update_branch_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_update_branch.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_update_branch_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_update_branch_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-imported-predicate-update-branch-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_host_is_positive(int32_t value) { return value > 0 ? 1 : 0; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_update_branch(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_update_branch(6) != 101) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_update_branch(4) != 107) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_update_branch(-1) != 107) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param imported-predicate update branch ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-merge-update-branch-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param merge update branch ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_merge_update_branch_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_merge_update_branch_preservation_source.gst"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_BLOCK_PARAM_MERGE_UPDATE_BRANCH_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-block-param-merge-update-branch-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_update_branch_ingestion_native_guard: guard-cranelift-compiler-mir-block-param-merge-update-branch-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_update_branch_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_update_branch_ingestion_fixture: compiler/fixtures/native_backend_block_param_merge_update_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_update_branch_ingestion_fixture_producer_entry: mir_emit_native_backend_block_param_merge_update_branch_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_update_branch_ingestion_object_artifact: build/guards/cranelift_compiler_mir_block_param_merge_update_branch_ingestion_native/tiny_native_backend_compiler_mir_ingested_block_param_merge_update_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_update_branch_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_update_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_update_branch_ingestion_source_fixture: compiler/mir_feature_block_param_merge_update_branch_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_update_branch_ingestion_lowering_entry: fixture_only_block_param_merge_update_branch_serialization' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_update_branch_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_block_param_merge_update_branch_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_update_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamAddI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_add_value: 4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: BranchBlockParamPositiveToI32Literals' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_then_value: 181' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_else_value: 191' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_target: join' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_4_target: join' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_terminator: ReturnBlockParam' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_return_param: 0' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_param_merge_update_branch(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut adjusted := input + 4;' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-block-param-merge-update-branch-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_block_param_merge_update_branch_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_UPDATE_BRANCH_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::ReturnBlockParamI32(0)' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_merge_update_branch_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_update_branch.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_update_branch_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_update_branch_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-merge-update-branch-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_merge_update_branch(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_update_branch(1) != 181) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_update_branch(-4) != 191) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_update_branch(-9) != 191) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param merge update branch ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-merge-imported-call-return-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param merge imported-call return ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_merge_imported_call_return_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_merge_imported_call_return_preservation_source.gst"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-block-param-merge-imported-call-return-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_call_return_ingestion_native_guard: guard-cranelift-compiler-mir-block-param-merge-imported-call-return-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_call_return_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_call_return_ingestion_fixture: compiler/fixtures/native_backend_block_param_merge_imported_call_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_call_return_ingestion_fixture_producer_entry: mir_emit_native_backend_block_param_merge_imported_call_return_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_call_return_ingestion_object_artifact: build/guards/cranelift_compiler_mir_block_param_merge_imported_call_return_ingestion_native/tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_call_return_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_call_return_ingestion_imported_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return_host_add' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_call_return_ingestion_source_fixture: compiler/mir_feature_block_param_merge_imported_call_return_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_call_return_ingestion_lowering_entry: fixture_only_block_param_merge_imported_call_return_serialization' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_call_return_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_block_param_merge_imported_call_return_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_imported_call_return.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'imported_function_0_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return_host_add' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'imported_function_0_operation: HostAddI32' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamAddI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_add_value: 4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: BranchBlockParamPositiveToI32Literals' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_then_value: 211' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_else_value: 223' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_target: join' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_4_target: join' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_terminator: ReturnBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_call_literal: 5' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_param_merge_imported_call_return(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut adjusted := input + 4;' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-block-param-merge-imported-call-return-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_block_param_merge_imported_call_return_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'Linkage::Import' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_merge_imported_call_return_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-merge-imported-call-return-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return(1) != 216) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return(-4) != 228) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return(-9) != 228) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param merge imported-call return ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-merge-arm-update-imported-call-return-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param merge arm-update imported-call return ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_return_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_merge_arm_update_imported_call_return_preservation_source.gst"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-block-param-merge-arm-update-imported-call-return-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_native_guard: guard-cranelift-compiler-mir-block-param-merge-arm-update-imported-call-return-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_fixture: compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_fixture_producer_entry: mir_emit_native_backend_block_param_merge_arm_update_imported_call_return_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_object_artifact: build/guards/cranelift_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_native/tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_imported_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return_host_add' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_source_fixture: compiler/mir_feature_block_param_merge_arm_update_imported_call_return_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_lowering_entry: fixture_only_block_param_merge_arm_update_imported_call_return_serialization' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_block_param_merge_arm_update_imported_call_return_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_arm_update_imported_call_return.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'imported_function_0_operation: HostAddI32' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: BranchBlockParamPositiveToI32Literals' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_then_value: 211' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_else_value: 223' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_add_value: 7' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_4_add_value: 9' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_terminator: ReturnBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_call_literal: 5' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_param_merge_arm_update_imported_call_return(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut adjusted := input + 4;' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-block-param-merge-arm-update-imported-call-return-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'Linkage::Import' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-merge-arm-update-imported-call-return-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return(1) != 223) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return(-4) != 237) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return(-9) != 237) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param merge arm-update imported-call return ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-merge-arm-update-imported-call-branch-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param merge arm-update imported-call branch ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_branch_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_merge_arm_update_imported_call_branch_preservation_source.gst"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-block-param-merge-arm-update-imported-call-branch-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_native_guard: guard-cranelift-compiler-mir-block-param-merge-arm-update-imported-call-branch-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_fixture: compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_branch_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_fixture_producer_entry: mir_emit_native_backend_block_param_merge_arm_update_imported_call_branch_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_object_artifact: build/guards/cranelift_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_native/tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_imported_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch_host_add' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_source_fixture: compiler/mir_feature_block_param_merge_arm_update_imported_call_branch_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_lowering_entry: fixture_only_block_param_merge_arm_update_imported_call_branch_serialization' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_block_param_merge_arm_update_imported_call_branch_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_arm_update_imported_call_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'imported_function_0_operation: HostAddI32' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: BranchBlockParamPositiveToI32Literals' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_then_value: 211' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'branch_else_value: 223' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_add_value: 7' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_4_add_value: 9' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_terminator: BranchBlockParamImportedFunctionCallI32LiteralPositive' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_call_literal: -220' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_6_return_value: 241' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_7_return_value: 251' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_param_merge_arm_update_imported_call_branch(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut probed := merged - 220;' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-block-param-merge-arm-update-imported-call-branch-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_HOST_ADD_SYMBOL' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallI32LiteralPositive' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'Linkage::Import' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-merge-arm-update-imported-call-branch-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch(1) != 251) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch(-4) != 241) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch(-9) != 241) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param merge arm-update imported-call branch ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-merge-imported-branch-joined-return-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param merge imported-branch joined-return ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_merge_imported_branch_joined_return_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_merge_imported_branch_joined_return_preservation_source.gst"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_INGESTION_NATIVE_GUARD: guard-cranelift-compiler-mir-block-param-merge-imported-branch-joined-return-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_native_guard: guard-cranelift-compiler-mir-block-param-merge-imported-branch-joined-return-ingestion-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_fixture: compiler/fixtures/native_backend_block_param_merge_imported_branch_joined_return_ingestion.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_fixture_producer_entry: mir_emit_native_backend_block_param_merge_imported_branch_joined_return_ingestion_fixture' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_object_artifact: build/guards/cranelift_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_native/tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_imported_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return_host_add' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_source_fixture: compiler/mir_feature_block_param_merge_imported_branch_joined_return_preservation_source.gst' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_lowering_entry: fixture_only_block_param_merge_imported_branch_joined_return_serialization' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_seam_status: compiler_owned_fixture_to_experiment_only' "$manifest_doc" >/dev/null
    rg -n -F 'func mir_emit_native_backend_block_param_merge_imported_branch_joined_return_ingestion_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_imported_branch_joined_return.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_terminator: BranchBlockParamImportedFunctionCallI32LiteralPositive' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_call_literal: -220' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_6_terminator: JumpI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_6_value: 241' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_7_terminator: JumpI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_7_value: 251' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_8_terminator: ReturnBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_8_call_literal: 3' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'func tiny_block_param_merge_imported_branch_joined_return(input: int) int' "$source_fixture" >/dev/null
    rg -n -F 'mut probed := merged - 220;' "$source_fixture" >/dev/null
    rg -n -F 'compiler-mir-block-param-merge-imported-branch-joined-return-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'parse_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_fixture' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::JumpI32Literal' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallI32LiteralPositive' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal' compiler/experiments/cranelift/src/main.rs >/dev/null
    rg -n -F 'Linkage::Import' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-merge-imported-branch-joined-return-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return(1) != 254) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return(-4) != 244) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return(-9) != 244) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param merge imported-branch joined-return ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-merge-dual-imported-joined-return-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param merge dual-import joined-return ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_merge_dual_imported_joined_return_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_merge_dual_imported_joined_return_preservation_source.gst"
    just guard-cranelift-backend-surface
    if [ ! -f "$fixture" ]; then
      echo "Missing dual-import joined-return fixture: $fixture"
      exit 1
    fi
    echo "ℹ️  Building dual-import joined-return object from $fixture"
    build_dir="build/guards/cranelift_compiler_mir_block_param_merge_dual_imported_joined_return_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-merge-dual-imported-joined-return-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return_branch_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return_return_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return(1) != 255) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return(-4) != 245) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return(-9) != 245) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param merge dual-import joined-return ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-imported-materialize-branch-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param imported materialize branch ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_imported_materialize_branch_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_imported_materialize_branch_preservation_source.gst"
    just guard-cranelift-backend-surface
    test -f "$manifest_doc"
    test -f "$fixture"
    test -f "$source_fixture"
    rg -n -F 'guard-cranelift-compiler-mir-block-param-imported-materialize-branch-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_imported_materialize_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_call_literal: -5' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: BranchBlockParamPositiveToI32Literals' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-block-param-imported-materialize-branch-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_imported_materialize_branch_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_branch.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_branch_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_branch_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-imported-materialize-branch-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_branch_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_branch(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_branch(8) != 271) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_branch(5) != 283) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_branch(-2) != 283) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param imported materialize branch ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-local-materialize-branch-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param local materialize branch ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_local_materialize_branch_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_local_materialize_branch_preservation_source.gst"
    just guard-cranelift-backend-surface
    test -f "$manifest_doc"
    test -f "$fixture"
    test -f "$source_fixture"
    rg -n -F 'guard-cranelift-compiler-mir-block-param-local-materialize-branch-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_local_materialize_branch.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamLocalFunctionCall' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'local_function_0_add_value: 1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: BranchBlockParamPositiveToI32Literals' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-block-param-local-materialize-branch-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_local_materialize_branch_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_branch.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_branch_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_branch_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-local-materialize-branch-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_branch(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_branch(8) != 293) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_branch(-1) != 307) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_branch(-9) != 307) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param local materialize branch ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-imported-materialize-return-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param imported materialize return ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_imported_materialize_return_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_imported_materialize_return_preservation_source.gst"
    just guard-cranelift-backend-surface
    test -f "$manifest_doc"
    test -f "$fixture"
    test -f "$source_fixture"
    rg -n -F 'guard-cranelift-compiler-mir-block-param-imported-materialize-return-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_imported_materialize_return.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_terminator: ReturnBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_call_literal: 13' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-block-param-imported-materialize-return-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_imported_materialize_return_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_return.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_return_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_return_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-imported-materialize-return-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_return_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_return(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_return(8) != 344) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_return(5) != 360) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_return(-2) != 360) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param imported materialize return ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-local-materialize-return-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param local materialize return ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_local_materialize_return_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_local_materialize_return_preservation_source.gst"
    just guard-cranelift-backend-surface
    test -f "$manifest_doc"
    test -f "$fixture"
    test -f "$source_fixture"
    rg -n -F 'guard-cranelift-compiler-mir-block-param-local-materialize-return-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_local_materialize_return.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'local_function_0_add_value: 2' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamLocalFunctionCall' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_terminator: ReturnBlockParamLocalFunctionCall' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-block-param-local-materialize-return-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_local_materialize_return_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_return.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_return_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_return_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-local-materialize-return-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_return(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_return(8) != 403) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_return(-2) != 423) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_return(-9) != 423) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param local materialize return ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-dual-materialize-return-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param dual materialize return ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_dual_materialize_return_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_dual_materialize_return_preservation_source.gst"
    just guard-cranelift-backend-surface
    test -f "$manifest_doc"
    test -f "$fixture"
    test -f "$source_fixture"
    rg -n -F 'guard-cranelift-compiler-mir-block-param-dual-materialize-return-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_dual_materialize_return.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: JumpBlockParamLocalFunctionCall' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_4_terminator: ReturnBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'local_function_0_add_value: 3' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-block-param-dual-materialize-return-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_dual_materialize_return_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-dual-materialize-return-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return(8) != 518) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return(2) != 540) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return(-9) != 540) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param dual materialize return ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-local-first-dual-materialize-return-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param local-first dual materialize return ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_local_first_dual_materialize_return_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_local_first_dual_materialize_return_preservation_source.gst"
    just guard-cranelift-backend-surface
    test -f "$manifest_doc"
    test -f "$fixture"
    test -f "$source_fixture"
    rg -n -F 'guard-cranelift-compiler-mir-block-param-local-first-dual-materialize-return-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_local_first_dual_materialize_return.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamLocalFunctionCall' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: JumpBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_4_terminator: ReturnBlockParamLocalFunctionCall' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'local_function_0_add_value: 4' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-block-param-local-first-dual-materialize-return-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_local_first_dual_materialize_return_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-local-first-dual-materialize-return-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return(8) != 605) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return(3) != 635) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return(-9) != 635) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param local-first dual materialize return ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-triple-materialize-return-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param triple materialize return ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_triple_materialize_return_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_triple_materialize_return_preservation_source.gst"
    just guard-cranelift-backend-surface
    test -f "$manifest_doc"
    test -f "$fixture"
    test -f "$source_fixture"
    rg -n -F 'guard-cranelift-compiler-mir-block-param-triple-materialize-return-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_triple_materialize_return.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: JumpBlockParamLocalFunctionCall' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_terminator: JumpBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_terminator: ReturnBlockParamLocalFunctionCall' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-block-param-triple-materialize-return-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_triple_materialize_return_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-triple-materialize-return-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return(5) != 707) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return(1) != 739) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return(-9) != 739) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param triple materialize return ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-quad-materialize-return-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param quad materialize return ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_quad_materialize_return_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_quad_materialize_return_preservation_source.gst"
    just guard-cranelift-backend-surface
    test -f "$manifest_doc"
    test -f "$fixture"
    test -f "$source_fixture"
    rg -n -F 'guard-cranelift-compiler-mir-block-param-quad-materialize-return-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_quad_materialize_return.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamLocalFunctionCall' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: JumpBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_terminator: JumpBlockParamLocalFunctionCall' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_4_terminator: JumpBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_6_terminator: ReturnBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-block-param-quad-materialize-return-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_quad_materialize_return_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-quad-materialize-return-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return(5) != 830) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return(2) != 872) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return(-9) != 872) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param quad materialize return ingestion seam native smoke passed."

guard-cranelift-compiler-mir-block-param-quint-materialize-return-ingestion-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Native compiling compiler-owned MIR block-param quint materialize return ingestion seam smoke."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    fixture="compiler/fixtures/native_backend_block_param_quint_materialize_return_ingestion.mir"
    source_fixture="compiler/mir_feature_block_param_quint_materialize_return_preservation_source.gst"
    just guard-cranelift-backend-surface
    test -f "$manifest_doc"
    test -f "$fixture"
    test -f "$source_fixture"
    rg -n -F 'guard-cranelift-compiler-mir-block-param-quint-materialize-return-ingestion-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_quint_materialize_return.v1' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_1_terminator: JumpBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_2_terminator: JumpBlockParamLocalFunctionCall' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_3_terminator: JumpBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_4_terminator: JumpBlockParamLocalFunctionCall' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_5_terminator: JumpBlockParamImportedFunctionCallI32Literal' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'block_7_terminator: ReturnBlockParamLocalFunctionCall' "$fixture" compiler/mir.gst >/dev/null
    rg -n -F 'compiler-mir-block-param-quint-materialize-return-ingestion-object' compiler/experiments/cranelift/src/main.rs >/dev/null
    build_dir="build/guards/cranelift_compiler_mir_block_param_quint_materialize_return_ingestion_native"
    object_file="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return.o"
    shim_c="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_main.c"
    binary="$build_dir/tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_bin"
    mkdir -p "$build_dir"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- compiler-mir-block-param-quint-materialize-return-ingestion-object "$fixture" "$object_file"
    test -s "$object_file"
    echo '#include <stdint.h>' > "$shim_c"
    echo 'int32_t tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_host_add(int32_t lhs, int32_t rhs) { return lhs + rhs; }' >> "$shim_c"
    echo 'extern int32_t tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return(int32_t input);' >> "$shim_c"
    echo 'int main(void) {' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return(5) != 927) return 1;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return(2) != 975) return 2;' >> "$shim_c"
    echo '  if (tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return(-9) != 975) return 3;' >> "$shim_c"
    echo '  return 0;' >> "$shim_c"
    echo '}' >> "$shim_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"
    "$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"
    "$binary"
    echo "✅ Compiler-owned MIR block-param quint materialize return ingestion seam native smoke passed."

guard-cranelift-compiler-mir-ingestion-invalid-fixtures-native-rejection:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking compiler-owned MIR ingestion rejects invalid fixtures..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    return_invalid="compiler/fixtures/native_backend_return_int_ingestion_invalid.mir"
    local_invalid="compiler/fixtures/native_backend_local_binding_read_ingestion_invalid.mir"
    branch_invalid="compiler/fixtures/native_backend_conditional_branch_ingestion_invalid.mir"
    add_invalid="compiler/fixtures/native_backend_add_i32_ingestion_invalid.mir"
    provenance_invalid="compiler/fixtures/native_backend_provenance_metadata_ingestion_invalid.mir"
    resource_invalid="compiler/fixtures/native_backend_resource_metadata_ingestion_invalid.mir"
    native_boundary_invalid="compiler/fixtures/native_backend_native_boundary_metadata_ingestion_invalid.mir"
    positive_branch_invalid="compiler/fixtures/native_backend_positive_i32_branch_ingestion_invalid.mir"
    block_jump_invalid="compiler/fixtures/native_backend_block_jump_ingestion_invalid.mir"
    block_local_branch_invalid="compiler/fixtures/native_backend_block_local_branch_ingestion_invalid.mir"
    block_local_update_branch_invalid="compiler/fixtures/native_backend_block_local_update_branch_ingestion_invalid.mir"
    block_two_local_update_branch_invalid="compiler/fixtures/native_backend_block_two_local_update_branch_ingestion_invalid.mir"
    block_local_branch_join_invalid="compiler/fixtures/native_backend_block_local_branch_join_ingestion_invalid.mir"
    block_param_update_branch_invalid="compiler/fixtures/native_backend_block_param_update_branch_ingestion_invalid.mir"
    block_param_local_call_branch_invalid="compiler/fixtures/native_backend_block_param_local_call_branch_ingestion_invalid.mir"
    block_param_imported_call_branch_invalid="compiler/fixtures/native_backend_block_param_imported_call_branch_ingestion_invalid.mir"
    block_param_imported_call_return_invalid="compiler/fixtures/native_backend_block_param_imported_call_return_ingestion_invalid.mir"
    block_param_imported_predicate_update_branch_invalid="compiler/fixtures/native_backend_block_param_imported_predicate_update_branch_ingestion_invalid.mir"
    block_param_merge_update_branch_invalid="compiler/fixtures/native_backend_block_param_merge_update_branch_ingestion_invalid.mir"
    block_param_merge_imported_call_return_invalid="compiler/fixtures/native_backend_block_param_merge_imported_call_return_ingestion_invalid.mir"
    block_param_merge_arm_update_imported_call_return_invalid="compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_return_ingestion_invalid.mir"
    block_param_merge_arm_update_imported_call_branch_invalid="compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_branch_ingestion_invalid.mir"
    block_param_merge_imported_branch_joined_return_invalid="compiler/fixtures/native_backend_block_param_merge_imported_branch_joined_return_ingestion_invalid.mir"
    block_param_merge_dual_imported_joined_return_invalid="compiler/fixtures/native_backend_block_param_merge_dual_imported_joined_return_ingestion_invalid.mir"
    block_param_imported_materialize_branch_invalid="compiler/fixtures/native_backend_block_param_imported_materialize_branch_ingestion_invalid.mir"
    block_param_local_materialize_branch_invalid="compiler/fixtures/native_backend_block_param_local_materialize_branch_ingestion_invalid.mir"
    block_param_imported_materialize_return_invalid="compiler/fixtures/native_backend_block_param_imported_materialize_return_ingestion_invalid.mir"
    block_param_local_materialize_return_invalid="compiler/fixtures/native_backend_block_param_local_materialize_return_ingestion_invalid.mir"
    block_param_dual_materialize_return_invalid="compiler/fixtures/native_backend_block_param_dual_materialize_return_ingestion_invalid.mir"
    block_param_local_first_dual_materialize_return_invalid="compiler/fixtures/native_backend_block_param_local_first_dual_materialize_return_ingestion_invalid.mir"
    block_param_triple_materialize_return_invalid="compiler/fixtures/native_backend_block_param_triple_materialize_return_ingestion_invalid.mir"
    block_param_quad_materialize_return_invalid="compiler/fixtures/native_backend_block_param_quad_materialize_return_ingestion_invalid.mir"
    block_param_quint_materialize_return_invalid="compiler/fixtures/native_backend_block_param_quint_materialize_return_ingestion_invalid.mir"
    build_dir="build/guards/cranelift_compiler_mir_ingestion_invalid_fixture_rejection"
    mkdir -p "$build_dir"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_COMPILER_MIR_INGESTION_INVALID_FIXTURES_NATIVE_GUARD: guard-cranelift-compiler-mir-ingestion-invalid-fixtures-native-rejection' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_fixtures_native_guard: guard-cranelift-compiler-mir-ingestion-invalid-fixtures-native-rejection' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_return_int_fixture: compiler/fixtures/native_backend_return_int_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_local_binding_read_fixture: compiler/fixtures/native_backend_local_binding_read_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_conditional_branch_fixture: compiler/fixtures/native_backend_conditional_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_add_i32_fixture: compiler/fixtures/native_backend_add_i32_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_provenance_metadata_fixture: compiler/fixtures/native_backend_provenance_metadata_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_resource_metadata_fixture: compiler/fixtures/native_backend_resource_metadata_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_native_boundary_metadata_fixture: compiler/fixtures/native_backend_native_boundary_metadata_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_positive_i32_branch_fixture: compiler/fixtures/native_backend_positive_i32_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_jump_fixture: compiler/fixtures/native_backend_block_jump_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_local_branch_fixture: compiler/fixtures/native_backend_block_local_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_local_update_branch_fixture: compiler/fixtures/native_backend_block_local_update_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_two_local_update_branch_fixture: compiler/fixtures/native_backend_block_two_local_update_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_local_branch_join_fixture: compiler/fixtures/native_backend_block_local_branch_join_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_update_branch_fixture: compiler/fixtures/native_backend_block_param_update_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_local_call_branch_fixture: compiler/fixtures/native_backend_block_param_local_call_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_imported_call_branch_fixture: compiler/fixtures/native_backend_block_param_imported_call_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_imported_call_return_fixture: compiler/fixtures/native_backend_block_param_imported_call_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_imported_predicate_update_branch_fixture: compiler/fixtures/native_backend_block_param_imported_predicate_update_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_merge_update_branch_fixture: compiler/fixtures/native_backend_block_param_merge_update_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_merge_imported_call_return_fixture: compiler/fixtures/native_backend_block_param_merge_imported_call_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_merge_arm_update_imported_call_return_fixture: compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_merge_arm_update_imported_call_branch_fixture: compiler/fixtures/native_backend_block_param_merge_arm_update_imported_call_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_merge_imported_branch_joined_return_fixture: compiler/fixtures/native_backend_block_param_merge_imported_branch_joined_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_merge_dual_imported_joined_return_fixture: compiler/fixtures/native_backend_block_param_merge_dual_imported_joined_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_imported_materialize_branch_fixture: compiler/fixtures/native_backend_block_param_imported_materialize_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_local_materialize_branch_fixture: compiler/fixtures/native_backend_block_param_local_materialize_branch_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_imported_materialize_return_fixture: compiler/fixtures/native_backend_block_param_imported_materialize_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_local_materialize_return_fixture: compiler/fixtures/native_backend_block_param_local_materialize_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_dual_materialize_return_fixture: compiler/fixtures/native_backend_block_param_dual_materialize_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_local_first_dual_materialize_return_fixture: compiler/fixtures/native_backend_block_param_local_first_dual_materialize_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_triple_materialize_return_fixture: compiler/fixtures/native_backend_block_param_triple_materialize_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_quad_materialize_return_fixture: compiler/fixtures/native_backend_block_param_quad_materialize_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_block_param_quint_materialize_return_fixture: compiler/fixtures/native_backend_block_param_quint_materialize_return_ingestion_invalid.mir' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_rejection_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_compiler_mir_ingestion_invalid_rejection_status: malformed_compiler_owned_fixtures_rejected_before_object_emission' "$manifest_doc" >/dev/null
    rg -n -F 'return_value: 9' "$return_invalid" >/dev/null
    rg -n -F 'statement_0_value: 9' "$local_invalid" >/dev/null
    rg -n -F 'branch_condition_value: 0' "$branch_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.add_i32.v1' "$add_invalid" >/dev/null
    rg -n -F 'expected_case_0_result: 6' "$add_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.provenance_metadata.v1' "$provenance_invalid" >/dev/null
    rg -n -F 'provenance_0_kind: NativeBoundary' "$provenance_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.resource_metadata.v1' "$resource_invalid" >/dev/null
    rg -n -F 'resource_0_state: Moved' "$resource_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.native_boundary_metadata.v1' "$native_boundary_invalid" >/dev/null
    rg -n -F 'native_boundary_0_kind: LayoutSensitiveCall' "$native_boundary_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.positive_i32_branch.v1' "$positive_branch_invalid" >/dev/null
    rg -n -F 'block_1_return_value: 8' "$positive_branch_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_jump.v1' "$block_jump_invalid" >/dev/null
    rg -n -F 'block_1_return_value: 2' "$block_jump_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_local_branch.v1' "$block_local_branch_invalid" >/dev/null
    rg -n -F 'block_1_return_value: 44' "$block_local_branch_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_local_update_branch.v1' "$block_local_update_branch_invalid" >/dev/null
    rg -n -F 'block_2_return_value: 54' "$block_local_update_branch_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_two_local_update_branch.v1' "$block_two_local_update_branch_invalid" >/dev/null
    rg -n -F 'block_2_return_value: 62' "$block_two_local_update_branch_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_local_branch_join.v1' "$block_local_branch_join_invalid" >/dev/null
    rg -n -F 'block_1_statement_0_value: 5' "$block_local_branch_join_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_update_branch.v1' "$block_param_update_branch_invalid" >/dev/null
    rg -n -F 'block_3_return_value: 68' "$block_param_update_branch_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_local_call_branch.v1' "$block_param_local_call_branch_invalid" >/dev/null
    rg -n -F 'block_2_return_value: 80' "$block_param_local_call_branch_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_imported_call_branch.v1' "$block_param_imported_call_branch_invalid" >/dev/null
    rg -n -F 'block_2_return_value: 90' "$block_param_imported_call_branch_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_imported_call_return.v1' "$block_param_imported_call_return_invalid" >/dev/null
    rg -n -F 'block_1_call_literal: 12' "$block_param_imported_call_return_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_imported_predicate_update_branch.v1' "$block_param_imported_predicate_update_branch_invalid" >/dev/null
    rg -n -F 'block_3_return_value: 102' "$block_param_imported_predicate_update_branch_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_update_branch.v1' "$block_param_merge_update_branch_invalid" >/dev/null
    rg -n -F 'branch_then_value: 182' "$block_param_merge_update_branch_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_imported_call_return.v1' "$block_param_merge_imported_call_return_invalid" >/dev/null
    rg -n -F 'branch_then_value: 212' "$block_param_merge_imported_call_return_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_arm_update_imported_call_return.v1' "$block_param_merge_arm_update_imported_call_return_invalid" >/dev/null
    rg -n -F 'block_3_add_value: 8' "$block_param_merge_arm_update_imported_call_return_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_arm_update_imported_call_branch.v1' "$block_param_merge_arm_update_imported_call_branch_invalid" >/dev/null
    rg -n -F 'block_3_add_value: 8' "$block_param_merge_arm_update_imported_call_branch_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_merge_imported_branch_joined_return.v1' "$block_param_merge_imported_branch_joined_return_invalid" >/dev/null
    rg -n -F 'block_3_add_value: 8' "$block_param_merge_imported_branch_joined_return_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_local_materialize_return.v1' "$block_param_local_materialize_return_invalid" >/dev/null
    rg -n -F 'local_function_0_add_value: 3' "$block_param_local_materialize_return_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_dual_materialize_return.v1' "$block_param_dual_materialize_return_invalid" >/dev/null
    rg -n -F 'local_function_0_add_value: 4' "$block_param_dual_materialize_return_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_local_first_dual_materialize_return.v1' "$block_param_local_first_dual_materialize_return_invalid" >/dev/null
    rg -n -F 'block_2_call_literal: -6' "$block_param_local_first_dual_materialize_return_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_triple_materialize_return.v1' "$block_param_triple_materialize_return_invalid" >/dev/null
    rg -n -F 'local_function_1_add_value: 7' "$block_param_triple_materialize_return_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_quad_materialize_return.v1' "$block_param_quad_materialize_return_invalid" >/dev/null
    rg -n -F 'local_function_1_add_value: 5' "$block_param_quad_materialize_return_invalid" >/dev/null
    rg -n -F 'format: gust.compiler_mir_ingestion.block_param_quint_materialize_return.v1' "$block_param_quint_materialize_return_invalid" >/dev/null
    rg -n -F 'local_function_2_add_value: 9' "$block_param_quint_materialize_return_invalid" >/dev/null
    check_rejected() {
      command="$1"
      fixture="$2"
      label="$3"
      object_file="$build_dir/${label}.o"
      log_file="$build_dir/${label}.log"
      rm -f "$object_file" "$log_file"
      set +e
      cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- "$command" "$fixture" "$object_file" >"$log_file" 2>&1
      status="$?"
      set -e
      if [ "$status" = "0" ]; then
        echo "Expected invalid compiler-owned MIR fixture to be rejected for $label, but command succeeded."
        cat "$log_file"
        exit 1
      fi
      rg -n -F 'compiler MIR ingestion fixture' "$log_file" >/dev/null
      if [ -s "$object_file" ]; then
        echo "Invalid compiler-owned MIR fixture unexpectedly emitted a non-empty object for $label."
        ls -l "$object_file"
        cat "$log_file"
        exit 1
      fi
    }
    check_rejected compiler-mir-return-int-ingestion-object "$return_invalid" return_int_invalid
    check_rejected compiler-mir-local-binding-read-ingestion-object "$local_invalid" local_binding_read_invalid
    check_rejected compiler-mir-conditional-branch-ingestion-object "$branch_invalid" conditional_branch_invalid
    check_rejected compiler-mir-add-i32-ingestion-object "$add_invalid" add_i32_invalid
    check_rejected compiler-mir-provenance-metadata-ingestion-object "$provenance_invalid" provenance_metadata_invalid
    check_rejected compiler-mir-resource-metadata-ingestion-object "$resource_invalid" resource_metadata_invalid
    check_rejected compiler-mir-native-boundary-metadata-ingestion-object "$native_boundary_invalid" native_boundary_metadata_invalid
    check_rejected compiler-mir-positive-i32-branch-ingestion-object "$positive_branch_invalid" positive_i32_branch_invalid
    check_rejected compiler-mir-block-jump-ingestion-object "$block_jump_invalid" block_jump_invalid
    check_rejected compiler-mir-block-local-branch-ingestion-object "$block_local_branch_invalid" block_local_branch_invalid
    check_rejected compiler-mir-block-local-update-branch-ingestion-object "$block_local_update_branch_invalid" block_local_update_branch_invalid
    check_rejected compiler-mir-block-two-local-update-branch-ingestion-object "$block_two_local_update_branch_invalid" block_two_local_update_branch_invalid
    check_rejected compiler-mir-block-local-branch-join-ingestion-object "$block_local_branch_join_invalid" block_local_branch_join_invalid
    check_rejected compiler-mir-block-param-update-branch-ingestion-object "$block_param_update_branch_invalid" block_param_update_branch_invalid
    check_rejected compiler-mir-block-param-local-call-branch-ingestion-object "$block_param_local_call_branch_invalid" block_param_local_call_branch_invalid
    check_rejected compiler-mir-block-param-imported-call-branch-ingestion-object "$block_param_imported_call_branch_invalid" block_param_imported_call_branch_invalid
    check_rejected compiler-mir-block-param-imported-call-return-ingestion-object "$block_param_imported_call_return_invalid" block_param_imported_call_return_invalid
    check_rejected compiler-mir-block-param-imported-predicate-update-branch-ingestion-object "$block_param_imported_predicate_update_branch_invalid" block_param_imported_predicate_update_branch_invalid
    check_rejected compiler-mir-block-param-merge-update-branch-ingestion-object "$block_param_merge_update_branch_invalid" block_param_merge_update_branch_invalid
    check_rejected compiler-mir-block-param-merge-imported-call-return-ingestion-object "$block_param_merge_imported_call_return_invalid" block_param_merge_imported_call_return_invalid
    check_rejected compiler-mir-block-param-merge-arm-update-imported-call-return-ingestion-object "$block_param_merge_arm_update_imported_call_return_invalid" block_param_merge_arm_update_imported_call_return_invalid
    check_rejected compiler-mir-block-param-merge-arm-update-imported-call-branch-ingestion-object "$block_param_merge_arm_update_imported_call_branch_invalid" block_param_merge_arm_update_imported_call_branch_invalid
    check_rejected compiler-mir-block-param-merge-imported-branch-joined-return-ingestion-object "$block_param_merge_imported_branch_joined_return_invalid" block_param_merge_imported_branch_joined_return_invalid
    check_rejected compiler-mir-block-param-merge-dual-imported-joined-return-ingestion-object "$block_param_merge_dual_imported_joined_return_invalid" block_param_merge_dual_imported_joined_return_invalid
    check_rejected compiler-mir-block-param-imported-materialize-branch-ingestion-object "$block_param_imported_materialize_branch_invalid" block_param_imported_materialize_branch_invalid
    check_rejected compiler-mir-block-param-local-materialize-branch-ingestion-object "$block_param_local_materialize_branch_invalid" block_param_local_materialize_branch_invalid
    check_rejected compiler-mir-block-param-imported-materialize-return-ingestion-object "$block_param_imported_materialize_return_invalid" block_param_imported_materialize_return_invalid
    check_rejected compiler-mir-block-param-local-materialize-return-ingestion-object "$block_param_local_materialize_return_invalid" block_param_local_materialize_return_invalid
    check_rejected compiler-mir-block-param-dual-materialize-return-ingestion-object "$block_param_dual_materialize_return_invalid" block_param_dual_materialize_return_invalid
    check_rejected compiler-mir-block-param-local-first-dual-materialize-return-ingestion-object "$block_param_local_first_dual_materialize_return_invalid" block_param_local_first_dual_materialize_return_invalid
    check_rejected compiler-mir-block-param-triple-materialize-return-ingestion-object "$block_param_triple_materialize_return_invalid" block_param_triple_materialize_return_invalid
    check_rejected compiler-mir-block-param-quad-materialize-return-ingestion-object "$block_param_quad_materialize_return_invalid" block_param_quad_materialize_return_invalid
    check_rejected compiler-mir-block-param-quint-materialize-return-ingestion-object "$block_param_quint_materialize_return_invalid" block_param_quint_materialize_return_invalid
    echo "✅ Invalid compiler-owned MIR ingestion fixtures were rejected before object emission."

guard-cranelift-mir-to-c-differential-native-smoke:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Differential native smoke: experimental Cranelift fixtures vs MIR-to-C fixtures..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_CODEGEN_STATUS: return_int_local_binding_branch_differential_fixture_only' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_DIFFERENTIAL_NATIVE_GUARD: guard-cranelift-mir-to-c-differential-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_differential_return_int_pair: tiny_cranelift_return_int == tiny_return_int' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_return_int_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_return_int_object_artifact: build/guards/cranelift_return_int_native/tiny_cranelift_return_int.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_local_binding_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_local_binding_object_artifact: build/guards/cranelift_local_binding_native/tiny_cranelift_local_binding_read.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_differential_local_binding_pair: tiny_cranelift_local_binding_read == tiny_local_binding_read' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_differential_branch_pair: tiny_cranelift_conditional_branch == tiny_conditional_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_branch_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_branch_object_artifact: build/guards/cranelift_conditional_branch_native/tiny_cranelift_conditional_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'int tiny_return_int(void) { return 1; }' compiler/mir.gst compiler/mir_to_c_return_int_literal_smoke_test_entry.gst justfile >/dev/null
    rg -n -F 'int tiny_local_binding_read(void) { int value = 2; return value; }' compiler/mir.gst compiler/mir_to_c_local_binding_read_smoke_test_entry.gst justfile >/dev/null
    rg -n -F 'int tiny_conditional_branch(void) { if (1) goto block_1; goto block_2; block_1: return 1; block_2: return 2; }' compiler/mir.gst compiler/mir_to_c_conditional_branch_smoke_test_entry.gst justfile >/dev/null
    mkdir -p build/guards/cranelift_mir_to_c_differential_native
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w}"

    run_c() {
      local source="$1"
      local binary="$2"
      "$CC_BIN" $CFLAGS_VAL "$source" -o "$binary"
      set +e
      "$binary"
      local status="$?"
      set -e
      printf '%s' "$status"
    }

    run_c_with_object() {
      local source="$1"
      local object_file="$2"
      local binary="$3"
      "$CC_BIN" $CFLAGS_VAL "$source" "$object_file" -o "$binary"
      set +e
      "$binary"
      local status="$?"
      set -e
      printf '%s' "$status"
    }

    compare_real_cranelift_return_int_case() {
      local mir_c="build/guards/cranelift_mir_to_c_differential_native/return_int_mir_to_c.c"
      local mir_bin="build/guards/cranelift_mir_to_c_differential_native/return_int_mir_to_c_bin"
      local cranelift_object="build/guards/cranelift_mir_to_c_differential_native/return_int_cranelift.o"
      local cranelift_shim_c="build/guards/cranelift_mir_to_c_differential_native/return_int_cranelift_main.c"
      local cranelift_bin="build/guards/cranelift_mir_to_c_differential_native/return_int_cranelift_bin"
      printf '%s\n' 'int tiny_return_int(void) { return 1; }' > "$mir_c"
      printf '%s\n' 'int main(void) { return tiny_return_int(); }' >> "$mir_c"
      cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- return-int-object "$cranelift_object"
      if [ ! -s "$cranelift_object" ]; then
        echo "Expected Cranelift return-int object file to be generated at $cranelift_object"
        exit 1
      fi
      printf '%s\n' '#include <stdint.h>' > "$cranelift_shim_c"
      printf '%s\n' 'extern int32_t tiny_cranelift_return_int(void);' >> "$cranelift_shim_c"
      printf '%s\n' 'int main(void) { return tiny_cranelift_return_int(); }' >> "$cranelift_shim_c"
      local mir_status
      local cranelift_status
      mir_status="$(run_c "$mir_c" "$mir_bin")"
      cranelift_status="$(run_c_with_object "$cranelift_shim_c" "$cranelift_object" "$cranelift_bin")"
      if [ "$mir_status" != "$cranelift_status" ]; then
        echo "Differential mismatch for return_int: MIR-to-C exited $mir_status but real Cranelift object exited $cranelift_status."
        exit 1
      fi
      if [ "$mir_status" != "1" ]; then
        echo "Differential fixture return_int expected exit 1, got $mir_status."
        exit 1
      fi
      echo "✅ Differential fixture return_int matched exit 1 with a real Cranelift object."
    }

    compare_case() {
      local label="$1"
      local expected_status="$2"
      local mir_fn="$3"
      local mir_source="$4"
      local cranelift_fn="$5"
      local cranelift_source="$6"
      local mir_c="build/guards/cranelift_mir_to_c_differential_native/${label}_mir_to_c.c"
      local cranelift_c="build/guards/cranelift_mir_to_c_differential_native/${label}_cranelift.c"
      local mir_bin="build/guards/cranelift_mir_to_c_differential_native/${label}_mir_to_c_bin"
      local cranelift_bin="build/guards/cranelift_mir_to_c_differential_native/${label}_cranelift_bin"
      printf '%s\n' "$mir_source" > "$mir_c"
      printf '%s\n' "int main(void) { return ${mir_fn}(); }" >> "$mir_c"
      printf '%s\n' "$cranelift_source" > "$cranelift_c"
      printf '%s\n' "int main(void) { return ${cranelift_fn}(); }" >> "$cranelift_c"
      local mir_status
      local cranelift_status
      mir_status="$(run_c "$mir_c" "$mir_bin")"
      cranelift_status="$(run_c "$cranelift_c" "$cranelift_bin")"
      if [ "$mir_status" != "$cranelift_status" ]; then
        echo "Differential mismatch for $label: MIR-to-C exited $mir_status but Cranelift fixture exited $cranelift_status."
        exit 1
      fi
      if [ "$mir_status" != "$expected_status" ]; then
        echo "Differential fixture $label expected exit $expected_status, got $mir_status."
        exit 1
      fi
      echo "✅ Differential fixture $label matched exit $expected_status."
    }

    compare_real_cranelift_return_int_case

    local_binding_mir_c="build/guards/cranelift_mir_to_c_differential_native/local_binding_read_mir_to_c.c"
    local_binding_mir_bin="build/guards/cranelift_mir_to_c_differential_native/local_binding_read_mir_to_c_bin"
    local_binding_cranelift_object="build/guards/cranelift_mir_to_c_differential_native/local_binding_read_cranelift.o"
    local_binding_cranelift_shim_c="build/guards/cranelift_mir_to_c_differential_native/local_binding_read_cranelift_main.c"
    local_binding_cranelift_bin="build/guards/cranelift_mir_to_c_differential_native/local_binding_read_cranelift_bin"
    printf '%s\n' 'int tiny_local_binding_read(void) { int value = 2; return value; }' > "$local_binding_mir_c"
    printf '%s\n' 'int main(void) { return tiny_local_binding_read(); }' >> "$local_binding_mir_c"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- local-binding-read-object "$local_binding_cranelift_object"
    if [ ! -s "$local_binding_cranelift_object" ]; then
      echo "Expected Cranelift local-binding object file to be generated at $local_binding_cranelift_object"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$local_binding_cranelift_shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_local_binding_read(void);' >> "$local_binding_cranelift_shim_c"
    printf '%s\n' 'int main(void) { return tiny_cranelift_local_binding_read(); }' >> "$local_binding_cranelift_shim_c"
    local_binding_mir_status="$(run_c "$local_binding_mir_c" "$local_binding_mir_bin")"
    local_binding_cranelift_status="$(run_c_with_object "$local_binding_cranelift_shim_c" "$local_binding_cranelift_object" "$local_binding_cranelift_bin")"
    if [ "$local_binding_mir_status" != "$local_binding_cranelift_status" ]; then
      echo "Differential mismatch for local_binding_read: MIR-to-C exited $local_binding_mir_status but real Cranelift object exited $local_binding_cranelift_status."
      exit 1
    fi
    if [ "$local_binding_mir_status" != "2" ]; then
      echo "Differential fixture local_binding_read expected exit 2, got $local_binding_mir_status."
      exit 1
    fi
    echo "✅ Differential fixture local_binding_read matched exit 2 with a real Cranelift object."

    branch_mir_c="build/guards/cranelift_mir_to_c_differential_native/conditional_branch_mir_to_c.c"
    branch_mir_bin="build/guards/cranelift_mir_to_c_differential_native/conditional_branch_mir_to_c_bin"
    branch_cranelift_object="build/guards/cranelift_mir_to_c_differential_native/conditional_branch_cranelift.o"
    branch_cranelift_shim_c="build/guards/cranelift_mir_to_c_differential_native/conditional_branch_cranelift_main.c"
    branch_cranelift_bin="build/guards/cranelift_mir_to_c_differential_native/conditional_branch_cranelift_bin"
    printf '%s\n' 'int tiny_conditional_branch(void) { if (1) goto block_1; goto block_2; block_1: return 1; block_2: return 2; }' > "$branch_mir_c"
    printf '%s\n' 'int main(void) { return tiny_conditional_branch(); }' >> "$branch_mir_c"
    cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked -- conditional-branch-object "$branch_cranelift_object"
    if [ ! -s "$branch_cranelift_object" ]; then
      echo "Expected Cranelift conditional-branch object file to be generated at $branch_cranelift_object"
      exit 1
    fi
    printf '%s\n' '#include <stdint.h>' > "$branch_cranelift_shim_c"
    printf '%s\n' 'extern int32_t tiny_cranelift_conditional_branch(void);' >> "$branch_cranelift_shim_c"
    printf '%s\n' 'int main(void) { return tiny_cranelift_conditional_branch(); }' >> "$branch_cranelift_shim_c"
    branch_mir_status="$(run_c "$branch_mir_c" "$branch_mir_bin")"
    branch_cranelift_status="$(run_c_with_object "$branch_cranelift_shim_c" "$branch_cranelift_object" "$branch_cranelift_bin")"
    if [ "$branch_mir_status" != "$branch_cranelift_status" ]; then
      echo "Differential mismatch for conditional_branch: MIR-to-C exited $branch_mir_status but real Cranelift object exited $branch_cranelift_status."
      exit 1
    fi
    if [ "$branch_mir_status" != "1" ]; then
      echo "Differential fixture conditional_branch expected exit 1, got $branch_mir_status."
      exit 1
    fi
    echo "✅ Differential fixture conditional_branch matched exit 1 with a real Cranelift object."

    echo "✅ Cranelift/MIR-to-C differential native smoke passed."

guard-cranelift-dependency-beachhead:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Cranelift dependency beachhead..."
    experiment_dir="compiler/experiments/cranelift"
    manifest="$experiment_dir/Cargo.toml"
    lockfile="$experiment_dir/Cargo.lock"
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"

    if [ ! -f "$manifest" ]; then
      echo "Missing $manifest. Step 8 must keep Cranelift dependencies in an isolated experimental crate."
      exit 1
    fi
    if [ ! -f "$lockfile" ]; then
      echo "Missing $lockfile. Generate and commit it with:"
      echo "  cargo generate-lockfile --manifest-path $manifest"
      exit 1
    fi

    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_DEPENDENCY_BEACHHEAD_GUARD: guard-cranelift-dependency-beachhead' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_dependency_beachhead_guard: guard-cranelift-dependency-beachhead' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_experiment_dependency_manifest: compiler/experiments/cranelift/Cargo.toml' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_experiment_dependency_lockfile: compiler/experiments/cranelift/Cargo.lock' "$manifest_doc" >/dev/null
    rg -n -F 'forbidden_root_dependency: cranelift' "$manifest_doc" >/dev/null

    rg -n -F 'name = "gust-cranelift-experiment"' "$manifest" >/dev/null
    rg -n -F 'publish = false' "$manifest" >/dev/null
    rg -n -F 'cranelift-codegen = "=0.131.0"' "$manifest" >/dev/null
    rg -n -F 'cranelift-frontend = "=0.131.0"' "$manifest" >/dev/null
    rg -n -F 'cranelift-module = "=0.131.0"' "$manifest" >/dev/null
    rg -n -F 'cranelift-native = "=0.131.0"' "$manifest" >/dev/null
    rg -n -F 'cranelift-object = "=0.131.0"' "$manifest" >/dev/null

    rg -n -F 'name = "cranelift-codegen"' "$lockfile" >/dev/null
    rg -n -F 'name = "cranelift-frontend"' "$lockfile" >/dev/null
    rg -n -F 'name = "cranelift-module"' "$lockfile" >/dev/null
    rg -n -F 'name = "cranelift-native"' "$lockfile" >/dev/null
    rg -n -F 'name = "cranelift-object"' "$lockfile" >/dev/null
    rg -n -F 'version = "0.131.0"' "$lockfile" >/dev/null

    root_dependency_refs="$(rg -n -i -F 'cranelift' Cargo.toml Cargo.lock 2>/dev/null || true)"
    if [ -n "$root_dependency_refs" ]; then
      echo "Root compiler Cargo manifests must not depend on Cranelift yet:"
      echo "$root_dependency_refs"
      exit 1
    fi

    production_refs="$(rg -n -i 'cranelift_codegen|cranelift_frontend|cranelift_module|cranelift_native|cranelift_object|CraneliftBackend|backend[[:space:]]*[:=][[:space:]]*cranelift|--backend[=[:space:]]*cranelift' compiler src tests Cargo.toml Cargo.lock Makefile 2>/dev/null | rg -v '^compiler/experiments/cranelift/' | rg -v '^compiler/CRANELIFT_EXPERIMENT_MANIFEST\.md:' || true)"
    if [ -n "$production_refs" ]; then
      echo "Cranelift dependency beachhead must not add production codegen routes or imports yet:"
      echo "$production_refs"
      exit 1
    fi

    cargo metadata --manifest-path "$manifest" --locked --format-version 1 >/dev/null
    cargo check --manifest-path "$manifest" --locked --all-targets
    echo "✅ Cranelift dependency beachhead passed: deps are isolated, locked, and production routing remains MIR-to-C."

guard-cranelift-no-fixture-regression:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Cranelift real-object smoke no-fixture regression..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-backend-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_NO_FIXTURE_REGRESSION_GUARD: guard-cranelift-no-fixture-regression' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_no_fixture_regression_guard: guard-cranelift-no-fixture-regression' "$manifest_doc" >/dev/null
    rg -n -F 'oracle_backend: mir_to_c' "$manifest_doc" >/dev/null
    rg -n -F 'production_route: mir_to_c' "$manifest_doc" >/dev/null
    smoke_count="$(rg -n '^real_cranelift_object_smoke: ' "$manifest_doc" | wc -l | tr -d '[:space:]')"
    if [ "$smoke_count" -lt "3" ]; then
      echo "Expected real Cranelift object smoke inventory in $manifest_doc, found $smoke_count entries."
      exit 1
    fi
    while IFS= read -r forbidden_line; do
      if [ -z "$forbidden_line" ]; then
        continue
      fi
      forbidden_pattern="${forbidden_line#*: }"
      if rg -n -F "$forbidden_pattern" compiler/experiments/cranelift/src/main.rs >/dev/null; then
        echo "Cranelift experiment regressed to a forbidden fixture-style definition instead of object emission:"
        echo "$forbidden_pattern"
        exit 1
      fi
    done < <(rg --no-line-number -F 'forbidden_cranelift_fixture_definition:' "$manifest_doc" || true)
    native_guard_tokens="$(awk '/^CRANELIFT_EXPERIMENT_ALLOWED_.*NATIVE_GUARD: guard-cranelift-/ { print $2 }' "$manifest_doc" | awk '!seen[$0]++')"
    if [ -z "$native_guard_tokens" ]; then
      echo "Expected CRANELIFT_EXPERIMENT_ALLOWED_*_NATIVE_GUARD inventory in $manifest_doc."
      exit 1
    fi
    while IFS= read -r guard_recipe; do
      if [ -z "$guard_recipe" ]; then
        continue
      fi
      rg -n -F "$guard_recipe:" justfile >/dev/null
    done <<< "$native_guard_tokens"
    cranelift_native_bodies="$(sed -n '/^guard-cranelift-return-int-native-smoke:/,/^guard-cranelift-mir-to-c-differential-native-smoke:/p' justfile)"
    printf '%s\n' "$cranelift_native_bodies" | rg -n -F 'cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml --locked --' >/dev/null
    printf '%s\n' "$cranelift_native_bodies" | rg -n -F -- '-object' >/dev/null
    echo "✅ Cranelift no-fixture regression guard passed."

guard-cranelift-experimental-backend-suite:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Running explicit experimental Cranelift backend suite..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-dependency-beachhead
    just guard-cranelift-experiment-manifest-surface
    just guard-cranelift-backend-surface
    just guard-cranelift-no-fixture-regression
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_BACKEND_SUITE_GUARD: guard-cranelift-experimental-backend-suite' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_backend_suite_guard: guard-cranelift-experimental-backend-suite' "$manifest_doc" >/dev/null
    suite_native_guards="$(awk '/^CRANELIFT_EXPERIMENT_ALLOWED_.*NATIVE_GUARD: guard-cranelift-/ { print $2 }' "$manifest_doc" | awk '!seen[$0]++')"
    if [ -z "$suite_native_guards" ]; then
      echo "Expected native Cranelift guard inventory in $manifest_doc."
      exit 1
    fi
    printf '%s\n' "$suite_native_guards" | rg -n -F 'guard-cranelift-mir-to-c-differential-native-smoke' >/dev/null
    while IFS= read -r guard_recipe; do
      if [ -z "$guard_recipe" ]; then
        continue
      fi
      echo "▶ $guard_recipe"
      just "$guard_recipe"
    done <<< "$suite_native_guards"
    echo "✅ Explicit experimental Cranelift backend suite passed."

guard-cranelift-experimental-backend-suite-shard shard:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔀 Running experimental Cranelift backend suite shard: {{shard}}"
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_BACKEND_SUITE_SHARD_GUARD: guard-cranelift-experimental-backend-suite-shard' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_backend_suite_shard_guard: guard-cranelift-experimental-backend-suite-shard' "$manifest_doc" >/dev/null
    suite_native_guards="$(awk '/^CRANELIFT_EXPERIMENT_ALLOWED_.*NATIVE_GUARD: guard-cranelift-/ { print $2 }' "$manifest_doc" | awk '!seen[$0]++')"
    if [ -z "$suite_native_guards" ]; then
      echo "Expected native Cranelift guard inventory in $manifest_doc."
      exit 1
    fi
    case "{{shard}}" in
      core)
        shard_guards="$(printf '%s\n' "$suite_native_guards" | rg -v '^guard-cranelift-compiler-mir-' | rg -v '^guard-cranelift-mir-to-cranelift-' || true)"
        ;;
      compiler-mir-basic)
        shard_guards="$(printf '%s\n' "$suite_native_guards" | rg '^guard-cranelift-compiler-mir-' | rg -v '^guard-cranelift-compiler-mir-block-' || true)"
        ;;
      compiler-mir-blocks)
        shard_guards="$(printf '%s\n' "$suite_native_guards" | rg '^guard-cranelift-compiler-mir-block-' || true)"
        ;;
      translators)
        printf '%s\n' "$suite_native_guards" | rg -n -F 'guard-cranelift-mir-to-cranelift-translator-seed-suite' >/dev/null
        shard_guards="guard-cranelift-mir-to-cranelift-translator-seed-suite"
        ;;
      *)
        echo "unknown Cranelift backend suite shard: {{shard}}"
        echo "expected one of: core, compiler-mir-basic, compiler-mir-blocks, translators"
        exit 1
        ;;
    esac
    if [ -z "$shard_guards" ]; then
      echo "Shard {{shard}} matched no Cranelift native guards."
      exit 1
    fi
    while IFS= read -r guard_recipe; do
      if [ -z "$guard_recipe" ]; then
        continue
      fi
      echo "▶ [{{shard}}] $guard_recipe"
      just "$guard_recipe"
    done <<< "$shard_guards"
    echo "✅ Experimental Cranelift backend suite shard passed: {{shard}}"

guard-cranelift-experimental-backend-suite-parallel:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "⚡ Running experimental Cranelift backend suite in parallel shards..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-dependency-beachhead
    just guard-cranelift-experiment-manifest-surface
    just guard-cranelift-backend-surface
    just guard-cranelift-no-fixture-regression
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_BACKEND_SUITE_PARALLEL_GUARD: guard-cranelift-experimental-backend-suite-parallel' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_BACKEND_SUITE_SHARD_GUARD: guard-cranelift-experimental-backend-suite-shard' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_backend_suite_parallel_guard: guard-cranelift-experimental-backend-suite-parallel' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_backend_suite_parallel_isolation: git_worktree_per_shard_to_avoid_to_log_collisions' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_backend_suite_parallel_shards: core, compiler-mir-basic, compiler-mir-blocks, translators' "$manifest_doc" >/dev/null
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Parallel Cranelift suite requires a git worktree so each shard can isolate to.log."
      exit 1
    fi
    root_dir="$(pwd)"
    log_dir="$root_dir/build/guards/cranelift_experimental_backend_suite_parallel"
    tmp_root="$(mktemp -d)"
    worktree_root="$tmp_root/worktrees"
    mkdir -p "$worktree_root"
    rm -rf "$log_dir"
    mkdir -p "$log_dir"
    cleanup() {
      if [ -d "$worktree_root" ]; then
        for worktree_path in "$worktree_root"/*; do
          if [ -d "$worktree_path" ]; then
            git worktree remove --force "$worktree_path" >/dev/null 2>&1 || true
          fi
        done
      fi
      rm -rf "$tmp_root"
    }
    trap cleanup EXIT
    shards=(core compiler-mir-basic compiler-mir-blocks translators)
    pids=()
    for shard in "${shards[@]}"; do
      worktree_path="$worktree_root/$shard"
      echo "  ↳ starting shard $shard"
      git worktree add --detach "$worktree_path" HEAD >/dev/null
      (
        cd "$worktree_path"
        export CARGO_TARGET_DIR="$root_dir/compiler/experiments/cranelift/target"
        just guard-cranelift-experimental-backend-suite-shard "$shard"
      ) > "$log_dir/$shard.log" 2>&1 &
      pids+=("$!")
    done
    status=0
    failed_shards=()
    for index in "${!pids[@]}"; do
      shard="${shards[$index]}"
      if wait "${pids[$index]}"; then
        echo "✅ shard passed: $shard"
      else
        echo "❌ shard failed: $shard"
        status=1
        failed_shards+=("$shard")
      fi
    done
    if [ "$status" -ne 0 ]; then
      for shard in "${failed_shards[@]}"; do
        echo "----- $shard log tail -----"
        tail -n 200 "$log_dir/$shard.log" || true
      done
      echo "Full shard logs are in $log_dir"
      exit "$status"
    fi
    echo "✅ Parallel experimental Cranelift backend suite passed. Logs: $log_dir"

guard-mir-feature-return-int-preservation:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking MIR feature preservation: return int literal..."
    just guard-mir-feature-harness-surface
    just guard-mir-feature-registry-surface
    feature_fixture="compiler/mir_feature_return_int_preservation_source.gst"
    build_dir="build/guards/mir_feature_return_int_preservation"
    old_c="$build_dir/old_ast_to_c_return_int.c"
    old_final_c="$build_dir/old_ast_to_c_return_int_final.c"
    old_binary="$build_dir/old_ast_to_c_return_int_bin"
    mkdir -p "$build_dir"
    rg -n -F 'func return_one() int' "$feature_fixture" >/dev/null
    rg -n -F 'return 1;' "$feature_fixture" >/dev/null
    rg -n -F 'os.Exit(result);' "$feature_fixture" >/dev/null
    echo "  ↳ old AST-to-C native behavior"
    ./gust "$feature_fixture" | grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > "$old_c"
    cat src/runtime.c "$old_c" > "$old_final_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w -pthread}"
    INCLUDES_VAL="${INCLUDES:--Isrc}"
    "$CC_BIN" $CFLAGS_VAL $INCLUDES_VAL "$old_final_c" -o "$old_binary"
    set +e
    "$old_binary"
    old_status="$?"
    set -e
    if [ "$old_status" != "1" ]; then
      echo "Expected old AST-to-C return-int fixture to exit with status 1, got $old_status"
      exit 1
    fi
    echo "  ↳ MIR lowering structural behavior"
    just guard-mir-lower-return-int-literal-smoke
    echo "  ↳ MIR-to-C textual behavior"
    just guard-mir-to-c-return-int-literal-smoke
    echo "  ↳ MIR-to-C native behavior"
    just guard-mir-to-c-return-int-literal-native-smoke
    echo "✅ MIR feature preservation passed: return int literal exits with status 1 on old and MIR-backed paths."

guard-mir-feature-local-binding-read-preservation:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking MIR feature preservation: local binding/read..."
    just guard-mir-feature-harness-surface
    just guard-mir-feature-registry-surface
    feature_fixture="compiler/mir_feature_local_binding_read_preservation_source.gst"
    build_dir="build/guards/mir_feature_local_binding_read_preservation"
    old_c="$build_dir/old_ast_to_c_local_binding_read.c"
    old_final_c="$build_dir/old_ast_to_c_local_binding_read_final.c"
    old_binary="$build_dir/old_ast_to_c_local_binding_read_bin"
    mkdir -p "$build_dir"
    rg -n -F 'func local_binding_read() int' "$feature_fixture" >/dev/null
    rg -n -F 'mut value := 2;' "$feature_fixture" >/dev/null
    rg -n -F 'return value;' "$feature_fixture" >/dev/null
    rg -n -F 'os.Exit(result);' "$feature_fixture" >/dev/null
    echo "  ↳ old AST-to-C native behavior"
    ./gust "$feature_fixture" | grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > "$old_c"
    cat src/runtime.c "$old_c" > "$old_final_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w -pthread}"
    INCLUDES_VAL="${INCLUDES:--Isrc}"
    "$CC_BIN" $CFLAGS_VAL $INCLUDES_VAL "$old_final_c" -o "$old_binary"
    set +e
    "$old_binary"
    old_status="$?"
    set -e
    if [ "$old_status" != "2" ]; then
      echo "Expected old AST-to-C local binding/read fixture to exit with status 2, got $old_status"
      exit 1
    fi
    echo "  ↳ MIR lowering structural behavior"
    just guard-mir-lower-local-binding-read-smoke
    echo "  ↳ MIR-to-C textual behavior"
    just guard-mir-to-c-local-binding-read-smoke
    echo "  ↳ MIR-to-C native behavior"
    just guard-mir-to-c-local-binding-read-native-smoke
    echo "✅ MIR feature preservation passed: local binding/read exits with status 2 on old and MIR-backed paths."

guard-mir-feature-if-else-return-int-preservation:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking MIR feature preservation: if/else return int..."
    just guard-mir-feature-harness-surface
    just guard-mir-feature-registry-surface
    feature_fixture="compiler/mir_feature_if_else_return_int_preservation_source.gst"
    build_dir="build/guards/mir_feature_if_else_return_int_preservation"
    old_c="$build_dir/old_ast_to_c_if_else_return_int.c"
    old_final_c="$build_dir/old_ast_to_c_if_else_return_int_final.c"
    old_binary="$build_dir/old_ast_to_c_if_else_return_int_bin"
    mkdir -p "$build_dir"
    rg -n -F 'func if_else_return_int() int' "$feature_fixture" >/dev/null
    rg -n -F 'if true {' "$feature_fixture" >/dev/null
    rg -n -F 'return 1;' "$feature_fixture" >/dev/null
    rg -n -F 'return 2;' "$feature_fixture" >/dev/null
    rg -n -F 'os.Exit(result);' "$feature_fixture" >/dev/null
    echo "  ↳ old AST-to-C native behavior"
    ./gust "$feature_fixture" | grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > "$old_c"
    cat src/runtime.c "$old_c" > "$old_final_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w -pthread}"
    INCLUDES_VAL="${INCLUDES:--Isrc}"
    "$CC_BIN" $CFLAGS_VAL $INCLUDES_VAL "$old_final_c" -o "$old_binary"
    set +e
    "$old_binary"
    old_status="$?"
    set -e
    if [ "$old_status" != "1" ]; then
      echo "Expected old AST-to-C if/else return-int fixture to exit with status 1, got $old_status"
      exit 1
    fi
    echo "  ↳ MIR lowering structural behavior"
    just guard-mir-lower-conditional-branch-smoke
    echo "  ↳ MIR-to-C textual behavior"
    just guard-mir-to-c-conditional-branch-smoke
    echo "  ↳ MIR-to-C native behavior"
    just guard-mir-to-c-conditional-branch-native-smoke
    echo "✅ MIR feature preservation passed: if/else return int exits with status 1 on old and MIR-backed paths."

guard-mir-feature-local-binding-read-provenance-metadata-preservation:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking MIR feature preservation: local binding/read with provenance metadata..."
    just guard-mir-feature-harness-surface
    just guard-mir-feature-registry-surface
    feature_fixture="compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst"
    build_dir="build/guards/mir_feature_local_binding_read_provenance_metadata_preservation"
    old_c="$build_dir/old_ast_to_c_local_binding_read_provenance_metadata.c"
    old_final_c="$build_dir/old_ast_to_c_local_binding_read_provenance_metadata_final.c"
    old_binary="$build_dir/old_ast_to_c_local_binding_read_provenance_metadata_bin"
    mkdir -p "$build_dir"
    rg -n -F 'func local_binding_read_provenance_metadata() int' "$feature_fixture" >/dev/null
    rg -n -F 'mut value := 2;' "$feature_fixture" >/dev/null
    rg -n -F 'return value;' "$feature_fixture" >/dev/null
    rg -n -F 'os.Exit(result);' "$feature_fixture" >/dev/null
    echo "  ↳ old AST-to-C native behavior"
    ./gust "$feature_fixture" | grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" > "$old_c"
    cat src/runtime.c "$old_c" > "$old_final_c"
    CC_BIN="${CC:-cc}"
    CFLAGS_VAL="${CFLAGS:--O0 -w -pthread}"
    INCLUDES_VAL="${INCLUDES:--Isrc}"
    "$CC_BIN" $CFLAGS_VAL $INCLUDES_VAL "$old_final_c" -o "$old_binary"
    set +e
    "$old_binary"
    old_status="$?"
    set -e
    if [ "$old_status" != "2" ]; then
      echo "Expected old AST-to-C local binding/read provenance metadata fixture to exit with status 2, got $old_status"
      exit 1
    fi
    echo "  ↳ MIR lowering provenance metadata behavior"
    just guard-mir-lower-provenance-metadata-smoke
    echo "  ↳ MIR-to-C provenance metadata textual behavior"
    just guard-mir-to-c-provenance-metadata-smoke
    echo "  ↳ MIR-to-C provenance metadata native behavior"
    just guard-mir-to-c-provenance-metadata-native-smoke
    echo "✅ MIR feature preservation passed: local binding/read provenance metadata exits with status 2 on old and MIR-backed paths."

guard-mir-feature-migration-suite:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking MIR feature migration suite..."
    just guard-mir-feature-harness-surface
    just guard-mir-feature-migration-registry
    just guard-mir-ast-to-c-retirement-manifest-surface
    just guard-mir-to-c-boring-surface
    just guard-cranelift-experiment-manifest-surface
    just guard-cranelift-backend-surface
    just guard-cranelift-return-int-native-smoke
    just guard-cranelift-local-binding-native-smoke
    just guard-mir-owned-return-int-literal-validation
    just guard-mir-feature-return-int-routed-execution
    just guard-mir-owned-local-binding-read-validation
    just guard-mir-feature-local-binding-read-routed-execution
    just guard-mir-owned-if-else-return-int-validation
    just guard-mir-feature-if-else-return-int-routed-execution
    just guard-mir-owned-local-binding-read-provenance-metadata-validation
    just guard-mir-feature-local-binding-read-provenance-metadata-routed-execution
    echo "✅ MIR feature migration suite passed."

guard-test-runner-bounded-concurrency-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking self-hosted test runner bounded concurrency surface..."
    rg -n -F 'max_test_runner_jobs := 4' tests/test_runner.gst >/dev/null
    rg -n -F 'Self-hosted Gust test runner max concurrent jobs' tests/test_runner.gst >/dev/null
    rg -n -F 'running_count < max_test_runner_jobs' tests/test_runner.gst >/dev/null
    rg -n -F 'completed_count < len(tests)' tests/test_runner.gst >/dev/null
    rg -n -F 'next_test_idx < len(tests)' tests/test_runner.gst >/dev/null
    spawn_count="$(rg -n -F 'std.Spawn(test_worker_task' tests/test_runner.gst | wc -l | tr -d '[:space:]')"
    if [ "$spawn_count" != "2" ]; then
      echo "Expected exactly two bounded test-worker spawn sites, found $spawn_count."
      rg -n -F 'std.Spawn(test_worker_task' tests/test_runner.gst || true
      exit 1
    fi
    if rg -n -F 'while i < len(tests)' tests/test_runner.gst >/dev/null; then
      echo "Self-hosted test runner must not spawn one worker per test before receiving results."
      exit 1
    fi
    echo "✅ Self-hosted test runner bounded concurrency surface guard passed."

guard-mir-lower-tiny-function-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking tiny MIR lowering surface..."
    rg -n -F 'func mir_lower_tiny_function_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_lower_return_int_literal_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_lower_block_jump_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_lower_conditional_branch_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_lower_resource_metadata_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_lower_provenance_metadata_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'func mir_lower_native_boundary_metadata_fixture' compiler/mir.gst >/dev/null
    rg -n -F 'tiny_shell' compiler/mir.gst compiler/mir_lower_tiny_function_fixture_smoke_test_entry.gst compiler/mir_lower_function_shell_smoke_test_entry.gst >/dev/null
    rg -n -F 'tiny_return_int' compiler/mir.gst compiler/mir_lower_return_int_literal_smoke_test_entry.gst >/dev/null
    rg -n -F 'tiny_block_jump' compiler/mir.gst compiler/mir_lower_block_jump_smoke_test_entry.gst >/dev/null
    rg -n -F 'tiny_conditional_branch' compiler/mir.gst compiler/mir_lower_conditional_branch_smoke_test_entry.gst >/dev/null
    rg -n -F 'tiny_resource_metadata_local' compiler/mir.gst compiler/mir_lower_resource_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'tiny_provenance_metadata_local_read' compiler/mir.gst compiler/mir_lower_provenance_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'tiny_native_boundary_metadata_function' compiler/mir.gst compiler/mir_lower_native_boundary_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirTerminator.ReturnVoid' compiler/mir_lower_function_shell_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirTerminator.Return' compiler/mir_lower_return_int_literal_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirTerminator.Jump' compiler/mir_lower_block_jump_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirTerminator.Branch' compiler/mir_lower_conditional_branch_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirResourceKind.LinearResource' compiler/mir.gst compiler/mir_lower_resource_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirResourceState.Owned' compiler/mir.gst compiler/mir_lower_resource_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirProvenanceKind.LocalBinding' compiler/mir.gst compiler/mir_lower_provenance_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirNativeBoundaryKind.RuntimeCall' compiler/mir.gst compiler/mir_lower_native_boundary_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirValue.IntLiteral' compiler/mir_lower_return_int_literal_smoke_test_entry.gst >/dev/null
    rg -n -F 'return_value.IntLiteral.val != 1' compiler/mir_lower_return_int_literal_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir lower tiny function fixture entry' compiler/mir_lower_tiny_function_fixture_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir lower function shell smoke' compiler/mir_lower_function_shell_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir lower return int literal smoke' compiler/mir_lower_return_int_literal_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir lower block jump smoke' compiler/mir_lower_block_jump_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir lower conditional branch smoke' compiler/mir_lower_conditional_branch_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir lower resource metadata smoke' compiler/mir_lower_resource_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir lower provenance metadata smoke' compiler/mir_lower_provenance_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir lower native boundary metadata smoke' compiler/mir_lower_native_boundary_metadata_smoke_test_entry.gst >/dev/null
    rg -n -F 'compiler/mir_lower_tiny_function_fixture_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_lower_function_shell_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_lower_return_int_literal_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_lower_block_jump_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_lower_conditional_branch_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_lower_resource_metadata_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_lower_provenance_metadata_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_lower_native_boundary_metadata_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'guard-mir-lower-tiny-function-fixture-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-lower-function-shell-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-lower-return-int-literal-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-lower-block-jump-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-lower-conditional-branch-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-lower-resource-metadata-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-lower-provenance-metadata-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-lower-native-boundary-metadata-smoke' justfile >/dev/null
    unexpected_lower_refs="$(rg -n -F 'mir_lower_' compiler/*.gst | rg -v 'compiler/mir.gst:|compiler/mir_lower_tiny_function_fixture_smoke_test_entry.gst:|compiler/mir_lower_function_shell_smoke_test_entry.gst:|compiler/mir_lower_return_int_literal_smoke_test_entry.gst:|compiler/mir_lower_local_binding_read_smoke_test_entry.gst:|compiler/mir_lower_resource_metadata_smoke_test_entry.gst:|compiler/mir_lower_provenance_metadata_smoke_test_entry.gst:|compiler/mir_lower_native_boundary_metadata_smoke_test_entry.gst:|compiler/mir_lower_block_jump_smoke_test_entry.gst:|compiler/mir_lower_conditional_branch_smoke_test_entry.gst:|compiler/mir_to_c_entry_smoke_test_entry.gst:|compiler/mir_to_c_function_shell_smoke_test_entry.gst:|compiler/mir_to_c_return_int_literal_smoke_test_entry.gst:|compiler/mir_to_c_local_binding_read_smoke_test_entry.gst:|compiler/mir_to_c_block_jump_smoke_test_entry.gst:|compiler/mir_to_c_conditional_branch_smoke_test_entry.gst:' || true)"
    if [ -n "$unexpected_lower_refs" ]; then
      echo "Unexpected MIR lowering reference outside fixture-only files:"
      echo "$unexpected_lower_refs"
      exit 1
    fi
    backend_refs="$(rg -n -F 'Cranelift' compiler/mir.gst compiler/mir_lower_tiny_function_fixture_smoke_test_entry.gst compiler/mir_lower_function_shell_smoke_test_entry.gst compiler/mir_lower_return_int_literal_smoke_test_entry.gst compiler/mir_lower_local_binding_read_smoke_test_entry.gst compiler/mir_lower_resource_metadata_smoke_test_entry.gst compiler/mir_lower_provenance_metadata_smoke_test_entry.gst compiler/mir_lower_native_boundary_metadata_smoke_test_entry.gst compiler/mir_lower_block_jump_smoke_test_entry.gst compiler/mir_lower_conditional_branch_smoke_test_entry.gst || true)"
    if [ -n "$backend_refs" ]; then
      echo "Tiny MIR lowering fixtures must not mention Cranelift yet:"
      echo "$backend_refs"
      exit 1
    fi
    echo "✅ Tiny MIR lowering surface guard passed."

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
    rg -n -F 'env_report_linear_resource_close_transition_rejected' compiler/typechecker.gst >/dev/null
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
    rg -n -F 'env_try_schedule_open_linear_resource_destructor(env, defer_resource_name_step52ai, ctx)' compiler/typechecker.gst >/dev/null
    rg -n -F 'real canonical Resource defer should mark the Resource destructor_scheduled' compiler/typechecker_resource_defer_real_path_scheduling_test_entry.gst >/dev/null
    rg -n -F 'real Resource defer scheduling must not mark the Resource closed' compiler/typechecker_resource_defer_real_path_scheduling_test_entry.gst >/dev/null
    just guard-positive compiler/typechecker_resource_defer_real_path_scheduling_test_entry.gst step52_defer_real_path_scheduling
    echo "✅ Step 5.2 real Resource defer scheduling path guard passed."

guard_step52_defer_close_manual_interaction:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 real Resource defer/manual-close interaction..."
    rg -n -F 'env_report_linear_resource_schedule_transition_rejected' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_resource_destructor_call_is_applicable' compiler/typechecker.gst >/dev/null
    rg -n -F 'schedule_destructor' compiler/typechecker.gst >/dev/null
    rg -n -F 'manual close after real defer scheduling should be rejected' compiler/typechecker_resource_defer_close_manual_interaction_test_entry.gst >/dev/null
    rg -n -F 'manual close after scheduling should emit LinearResourceDestructorAlreadyScheduled' compiler/typechecker_resource_defer_close_manual_interaction_test_entry.gst >/dev/null
    rg -n -F 'defer scheduling after manual close should emit LinearResourceInvalidTransfer' compiler/typechecker_resource_defer_close_manual_interaction_test_entry.gst >/dev/null
    just guard-positive compiler/typechecker_resource_defer_close_manual_interaction_test_entry.gst step52_defer_close_manual_interaction
    echo "✅ Step 5.2 real Resource defer/manual-close interaction guard passed."

guard_step52_defer_function_body_scheduled_terminal:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 real function-body scheduled Resource return/implicit-exit cleanup..."
    rg -n -F 'defer close_defer_function_body_payload(return_body_scheduled_resource);' compiler/typechecker_resource_defer_function_body_scheduled_terminal_test_entry.gst >/dev/null
    rg -n -F 'defer close_defer_function_body_payload(implicit_body_scheduled_resource);' compiler/typechecker_resource_defer_function_body_scheduled_terminal_test_entry.gst >/dev/null
    rg -n -F 'real function-body return defer scheduling should not emit diagnostics' compiler/typechecker_resource_defer_function_body_scheduled_terminal_test_entry.gst >/dev/null
    rg -n -F 'real function-body implicit-exit defer scheduling should not emit diagnostics' compiler/typechecker_resource_defer_function_body_scheduled_terminal_test_entry.gst >/dev/null
    rg -n -F 'pending control function should still emit exactly one LinearResourceMissingCleanup' compiler/typechecker_resource_defer_function_body_scheduled_terminal_test_entry.gst >/dev/null
    just guard-positive compiler/typechecker_resource_defer_function_body_scheduled_terminal_test_entry.gst step52_defer_function_body_scheduled_terminal
    echo "✅ Step 5.2 real function-body scheduled Resource return/implicit-exit cleanup guard passed."

guard_step52_open_directories_legacy_freeze:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 legacy open_directories behavior freeze..."
    rg -n -F 'open_directories' compiler/typechecker.gst compiler/typechecker_open_directories_legacy_freeze_test_entry.gst >/dev/null
    rg -n -F 'Directory resource variable' compiler/typechecker.gst compiler/typechecker_open_directories_legacy_freeze_test_entry.gst >/dev/null
    rg -n -F 'must be cleanly closed with os.CloseDir before leaving local scope' compiler/typechecker.gst compiler/typechecker_open_directories_legacy_freeze_test_entry.gst >/dev/null
    rg -n -F 'legacy os.CloseDir should clear open_directories entry' compiler/typechecker_open_directories_legacy_freeze_test_entry.gst >/dev/null
    rg -n -F 'legacy open_directories move-open-directory diagnostic drifted' compiler/typechecker_open_directories_legacy_freeze_test_entry.gst >/dev/null
    rg -n -F 'legacy open_directories function-exit leak diagnostic drifted' compiler/typechecker_open_directories_legacy_freeze_test_entry.gst >/dev/null
    just guard-positive compiler/typechecker_open_directories_legacy_freeze_test_entry.gst step52_open_directories_legacy_freeze
    echo "✅ Step 5.2 legacy open_directories behavior freeze guard passed."

guard_step52_directory_resource_parity_metadata:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 directory Resource parity metadata..."
    rg -n -F 'env_register_directory_resource_parity_metadata' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_register_struct_linear_metadata(env, "os_Dir_ctx", 1, ctx);' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_register_struct_linear_destructor(env, "os_Dir_ctx", "os.CloseDir", ctx);' compiler/typechecker.gst >/dev/null
    rg -n -F 'directory handle parity metadata should mark os_Dir_ctx linear' compiler/typechecker_directory_resource_parity_metadata_test_entry.gst >/dev/null
    rg -n -F 'directory Resource parity metadata must not populate legacy open_directories yet' compiler/typechecker_directory_resource_parity_metadata_test_entry.gst >/dev/null
    just guard-positive compiler/typechecker_directory_resource_parity_metadata_test_entry.gst step52_directory_resource_parity_metadata
    echo "✅ Step 5.2 directory Resource parity metadata guard passed."

guard_step52_directory_resource_shadow_tracking:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 directory Resource shadow tracking..."
    rg -n -F 'env_shadow_track_open_directory_resource' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_shadow_track_closed_directory_resource' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_open_linear_resource_is_directory_shadow' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_function_is_directory_close_destructor' compiler/typechecker.gst >/dev/null
    rg -n -F 'directory declaration should shadow-track an owned open_linear_resource' compiler/typechecker_directory_resource_shadow_tracking_test_entry.gst >/dev/null
    rg -n -F 'os.CloseDir should shadow-track closed open_linear_resource state' compiler/typechecker_directory_resource_shadow_tracking_test_entry.gst >/dev/null
    rg -n -F 'os.CloseDir directory shadow close should not also trigger generic Resource destructor-call tracking' compiler/typechecker_directory_resource_shadow_tracking_test_entry.gst >/dev/null
    rg -n -F 'direct generic destructor tracking helper should ignore os.CloseDir directory shadows' compiler/typechecker_directory_resource_shadow_tracking_test_entry.gst >/dev/null
    rg -n -F 'directory shadow records should require cleanup through the shared Resource predicate' compiler/typechecker_directory_resource_shadow_tracking_test_entry.gst >/dev/null
    rg -n -F 'directory shadow tracking must not emit generic Resource cleanup diagnostics' compiler/typechecker_directory_resource_shadow_tracking_test_entry.gst >/dev/null
    just guard-positive compiler/typechecker_directory_resource_shadow_tracking_test_entry.gst step52_directory_resource_shadow_tracking
    echo "✅ Step 5.2 directory Resource shadow tracking guard passed."

guard_step52_directory_resource_cleanup_boundary_routing:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 directory Resource cleanup-boundary routing..."
    rg -n -F 'env_open_directory_resource_requires_cleanup' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_open_linear_resource_should_emit_generic_cleanup_diagnostic' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_open_directory_resource_requires_cleanup(env, local_var, ctx)' compiler/typechecker.gst >/dev/null
    rg -n -F 'directory shadow should reuse Resource cleanup-required transition predicate' compiler/typechecker_directory_resource_cleanup_boundary_routing_test_entry.gst >/dev/null
    rg -n -F 'generic Resource cleanup boundary should skip directory shadow records' compiler/typechecker_directory_resource_cleanup_boundary_routing_test_entry.gst >/dev/null
    rg -n -F 'routed directory cleanup boundary should preserve legacy CloseDir diagnostic' compiler/typechecker_directory_resource_cleanup_boundary_routing_test_entry.gst >/dev/null
    just guard-positive compiler/typechecker_directory_resource_cleanup_boundary_routing_test_entry.gst step52_directory_resource_cleanup_boundary_routing
    echo "✅ Step 5.2 directory Resource cleanup-boundary routing guard passed."

guard_step52_directory_resource_close_diagnostics_routing:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 directory Resource close/double-close diagnostic routing..."
    rg -n -F 'env_report_linear_resource_close_transition_rejected' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_open_linear_resource_can_be_closed(env, name, ctx)' compiler/typechecker.gst >/dev/null
    rg -n -F 'close transition helper should preserve LinearResourceDoubleClose diagnostic' compiler/typechecker_directory_resource_close_diagnostics_routing_test_entry.gst >/dev/null
    rg -n -F 'close transition helper should preserve LinearResourceCloseAfterMove diagnostic' compiler/typechecker_directory_resource_close_diagnostics_routing_test_entry.gst >/dev/null
    rg -n -F 'directory close shadow helper should route successful close through shared transfer helper' compiler/typechecker_directory_resource_close_diagnostics_routing_test_entry.gst >/dev/null
    just guard-positive compiler/typechecker_directory_resource_close_diagnostics_routing_test_entry.gst step52_directory_resource_close_diagnostics_routing
    echo "✅ Step 5.2 directory Resource close/double-close diagnostic routing guard passed."

guard_step52_directory_resource_source_of_truth_flip:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 directory Resource source-of-truth flip..."
    rg -n -F 'env_open_directory_resource_compatibility_sync_from_open_directories' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_open_directory_resource_compatibility_mark_open' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_open_directory_resource_compatibility_mark_closed' compiler/typechecker.gst >/dev/null
    rg -n -F 'env_open_directory_resource_compatibility_mark_moved' compiler/typechecker.gst >/dev/null
    rg -n -F 'directory move-open diagnostic should read Resource source of truth without open_directories shim state' compiler/typechecker_directory_resource_source_of_truth_flip_test_entry.gst >/dev/null
    rg -n -F 'open_directories compatibility shim should sync into Resource cleanup source of truth' compiler/typechecker_directory_resource_source_of_truth_flip_test_entry.gst >/dev/null
    rg -n -F 'real directory declaration should still mirror into open_directories compatibility shim' compiler/typechecker_directory_resource_source_of_truth_flip_test_entry.gst >/dev/null
    just guard-positive compiler/typechecker_directory_resource_source_of_truth_flip_test_entry.gst step52_directory_resource_source_of_truth_flip
    echo "✅ Step 5.2 directory Resource source-of-truth flip guard passed."

guard_step52_directory_resource_no_open_directories_enforcement_reads:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Step 5.2 directory Resource no open_directories enforcement-read drift..."
    mkdir -p build/guards/step52_directory_resource_no_open_directories_enforcement_reads
    direct_reads_file="build/guards/step52_directory_resource_no_open_directories_enforcement_reads/open_directories_get_reads.txt"
    rg -n -F 'open_directories.Get' compiler/typechecker.gst > "$direct_reads_file" || true
    read_count="$(wc -l < "$direct_reads_file" | tr -d '[:space:]')"
    if [ "$read_count" != "1" ]; then
      echo "Expected exactly one compiler/typechecker.gst open_directories.Get read, owned by the compatibility sync shim. Found $read_count:"
      cat "$direct_reads_file"
      exit 1
    fi
    rg -n -F 'env_open_directory_resource_compatibility_sync_from_open_directories' compiler/typechecker.gst >/dev/null
    rg -n -F '(*env).open_directories.Get(variable_name).Ok == false' compiler/typechecker.gst >/dev/null
    echo "✅ Step 5.2 directory Resource no open_directories enforcement-read drift guard passed."

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
      guard_step52_defer_close_manual_interaction
      guard_step52_defer_function_body_scheduled_terminal
      guard_step52_open_directories_legacy_freeze
      guard_step52_directory_resource_parity_metadata
      guard_step52_directory_resource_shadow_tracking
      guard_step52_directory_resource_cleanup_boundary_routing
      guard_step52_directory_resource_close_diagnostics_routing
      guard_step52_directory_resource_source_of_truth_flip
      guard_step52_directory_resource_no_open_directories_enforcement_reads
      guard-mir-feature-migration-suite
      guard-test-runner-bounded-concurrency-surface
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
      guard_step52_defer_close_manual_interaction
      guard_step52_defer_function_body_scheduled_terminal
      guard_step52_open_directories_legacy_freeze
      guard_step52_directory_resource_parity_metadata
      guard_step52_directory_resource_shadow_tracking
      guard_step52_directory_resource_cleanup_boundary_routing
      guard_step52_directory_resource_close_diagnostics_routing
      guard_step52_directory_resource_source_of_truth_flip
      guard_step52_directory_resource_no_open_directories_enforcement_reads
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

test-fast-c:
    CC=cc CFLAGS="-O0 -w -pthread" make test

test-tree-sitter-fast-c:
    CC=cc CFLAGS="-O0 -w -pthread" make test_tree_sitter

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

make-test-suite-fast-c:
    CC=cc CFLAGS="-O0 -w -pthread" just make-test-suite

guard-step51-provenance-origin-spine-fast-c:
    CC=cc CFLAGS="-O0 -w -pthread" just guard_step51_provenance_origin_spine

make-test-guards-fast-c:
    CC=cc CFLAGS="-O0 -w -pthread" just make-test-guards

bootstrap-fast-c:
    CC=cc CFLAGS="-O0 -w -pthread" make bootstrap

validate-fast-c:
    git diff --check
    make gust
    just guard-step51-provenance-origin-spine-fast-c
    just make-test-guards-fast-c
    just test-fast-c
    just test-tree-sitter-fast-c
    just bootstrap-fast-c
    git diff --check

validate-native-fast-c:
    git diff --check
    make gust
    just make-test-suite-fast-c
    just bootstrap-fast-c
    git diff --check

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
    just guard_step52_defer_close_manual_interaction
    just guard_step52_defer_function_body_scheduled_terminal
    just guard_step52_open_directories_legacy_freeze
    just guard_step52_directory_resource_parity_metadata
    just guard_step52_directory_resource_shadow_tracking
    just guard_step52_directory_resource_cleanup_boundary_routing
    just guard_step52_directory_resource_close_diagnostics_routing
    just guard_step52_directory_resource_source_of_truth_flip
    just guard_step52_directory_resource_no_open_directories_enforcement_reads
    just run-step52-positive-batch
    just run-step52-negative-batch
    make test
    git diff --check
