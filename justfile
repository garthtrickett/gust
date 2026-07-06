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
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_RETURN_INT_NATIVE_GUARD: guard-cranelift-return-int-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_LOCAL_BINDING_NATIVE_GUARD: guard-cranelift-local-binding-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_BRANCH_NATIVE_GUARD: guard-cranelift-conditional-branch-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_DIFFERENTIAL_NATIVE_GUARD: guard-cranelift-mir-to-c-differential-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_BACKEND_SUITE_GUARD: guard-cranelift-experimental-backend-suite' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_DEPENDENCY_BEACHHEAD_GUARD: guard-cranelift-dependency-beachhead' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_NO_FIXTURE_REGRESSION_GUARD: guard-cranelift-no-fixture-regression' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_IDENTITY_I32_NATIVE_GUARD: guard-cranelift-identity-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_POSITIVE_I32_BRANCH_NATIVE_GUARD: guard-cranelift-positive-i32-branch-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_INCREMENT_LOCAL_I32_NATIVE_GUARD: guard-cranelift-increment-local-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_CALL_HELPER_I32_NATIVE_GUARD: guard-cranelift-call-helper-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_call_helper_i32_native_guard: guard-cranelift-call-helper-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_call_helper_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_call_helper_i32_object_artifact: build/guards/cranelift_call_helper_i32_native/tiny_cranelift_call_helper_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_EXTERN_CALL_I32_NATIVE_GUARD: guard-cranelift-extern-call-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_extern_call_i32_native_guard: guard-cranelift-extern-call-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_call_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_call_i32_object_artifact: build/guards/cranelift_extern_call_i32_native/tiny_cranelift_extern_call_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_call_i32_host_symbol: tiny_host_add_one_i32' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_EXTERN_ADD_I32_NATIVE_GUARD: guard-cranelift-extern-add-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_extern_add_i32_native_guard: guard-cranelift-extern-add-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_add_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_add_i32_object_artifact: build/guards/cranelift_extern_add_i32_native/tiny_cranelift_extern_add_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_add_i32_host_symbol: tiny_host_add_i32' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_EXTERN_PREDICATE_BRANCH_I32_NATIVE_GUARD: guard-cranelift-extern-predicate-branch-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_extern_predicate_branch_i32_native_guard: guard-cranelift-extern-predicate-branch-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_predicate_branch_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_predicate_branch_i32_object_artifact: build/guards/cranelift_extern_predicate_branch_i32_native/tiny_cranelift_extern_predicate_branch_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_predicate_branch_i32_host_symbol: tiny_host_is_positive_i32' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_RETURN_INT_NATIVE_GUARD: guard-cranelift-mir-return-int-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_return_int_native_guard: guard-cranelift-mir-return-int-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_return_int_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_return_int_object_artifact: build/guards/cranelift_mir_return_int_native/tiny_cranelift_mir_return_int.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_return_int_symbol: tiny_cranelift_mir_return_int' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_return_int_lowering_scaffold: TinyMirFunction' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_LOCAL_BINDING_READ_NATIVE_GUARD: guard-cranelift-mir-local-binding-read-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_local_binding_read_native_guard: guard-cranelift-mir-local-binding-read-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_local_binding_read_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_local_binding_read_object_artifact: build/guards/cranelift_mir_local_binding_read_native/tiny_cranelift_mir_local_binding_read.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_local_binding_read_symbol: tiny_cranelift_mir_local_binding_read' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_local_binding_read_lowering_scaffold: TinyMirStatement::LocalI32Set' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_CONDITIONAL_BRANCH_NATIVE_GUARD: guard-cranelift-mir-conditional-branch-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_conditional_branch_native_guard: guard-cranelift-mir-conditional-branch-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_conditional_branch_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_conditional_branch_object_artifact: build/guards/cranelift_mir_conditional_branch_native/tiny_cranelift_mir_conditional_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_conditional_branch_symbol: tiny_cranelift_mir_conditional_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_conditional_branch_lowering_scaffold: TinyMirTerminator::BranchI32Literal' "$manifest_doc" >/dev/null
    rg -n -F 'MIR_TO_C_BORING_GATE: guard-mir-to-c-boring-surface' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_ADD_I32_NATIVE_GUARD: guard-cranelift-mir-add-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'allowed_mir_add_i32_native_guard: guard-cranelift-mir-add-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_add_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_add_i32_object_artifact: build/guards/cranelift_mir_add_i32_native/tiny_cranelift_mir_add_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_add_i32_symbol: tiny_cranelift_mir_add_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_add_i32_lowering_scaffold: TinyMirTerminator::ReturnParamI32Add' "$manifest_doc" >/dev/null
    rg -n -F 'Cranelift is disabled by default.' "$manifest_doc" >/dev/null
    rg -n -F 'No production Cranelift codegen entry point exists yet.' "$manifest_doc" >/dev/null
    rg -n -F 'The only allowed real Cranelift codegen entry point is compiler/experiments/cranelift/src/main.rs for return-int, local-binding/read, conditional-branch, and add-i32 object emission.' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_experiment_dependency_manifest: compiler/experiments/cranelift/Cargo.toml' "$manifest_doc" >/dev/null
    rg -n -F 'No production compiler path may route to Cranelift yet.' "$manifest_doc" >/dev/null
    rg -n -F 'No `guard-cranelift-*` recipe is allowed except `guard-cranelift-experiment-manifest-surface`, `guard-cranelift-backend-surface`, `guard-cranelift-dependency-beachhead`, `guard-cranelift-experimental-backend-suite`, `guard-cranelift-no-fixture-regression`, `guard-cranelift-return-int-native-smoke`, `guard-cranelift-local-binding-native-smoke`, `guard-cranelift-local-binding-read-native-smoke`, `guard-cranelift-conditional-branch-native-smoke`, `guard-cranelift-branch-native-smoke`, `guard-cranelift-mir-to-c-differential-native-smoke`, and `guard-cranelift-differential-native-smoke`.' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_manifest: compiler/CRANELIFT_EXPERIMENT_MANIFEST.md' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_guard: guard-cranelift-experiment-manifest-surface' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_backend_surface_guard: guard-cranelift-backend-surface' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_return_int_native_guard: guard-cranelift-return-int-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_local_binding_native_guard: guard-cranelift-local-binding-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_branch_native_guard: guard-cranelift-conditional-branch-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_differential_native_guard: guard-cranelift-mir-to-c-differential-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_backend_suite_guard: guard-cranelift-experimental-backend-suite' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_dependency_beachhead_guard: guard-cranelift-dependency-beachhead' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_no_fixture_regression_guard: guard-cranelift-no-fixture-regression' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_identity_i32_native_guard: guard-cranelift-identity-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_identity_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_identity_i32_object_artifact: build/guards/cranelift_identity_i32_native/tiny_cranelift_identity_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_positive_i32_branch_native_guard: guard-cranelift-positive-i32-branch-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_positive_i32_branch_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_positive_i32_branch_object_artifact: build/guards/cranelift_positive_i32_branch_native/tiny_cranelift_positive_i32_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_increment_local_i32_native_guard: guard-cranelift-increment-local-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_increment_local_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_increment_local_i32_object_artifact: build/guards/cranelift_increment_local_i32_native/tiny_cranelift_increment_local_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_status: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_codegen_status: return_int_local_binding_branch_differential_fixture_only' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_backend_surface_status: differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_primary_route: mir_to_c' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_return_int_fixture: tiny_cranelift_return_int' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_return_int_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_return_int_object_artifact: build/guards/cranelift_return_int_native/tiny_cranelift_return_int.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_local_binding_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_local_binding_object_artifact: build/guards/cranelift_local_binding_native/tiny_cranelift_local_binding_read.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_local_binding_fixture: tiny_cranelift_local_binding_read' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_branch_fixture: tiny_cranelift_conditional_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_branch_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_branch_object_artifact: build/guards/cranelift_conditional_branch_native/tiny_cranelift_conditional_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_differential_return_int_pair: tiny_cranelift_return_int == tiny_return_int' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_differential_local_binding_pair: tiny_cranelift_local_binding_read == tiny_local_binding_read' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_differential_branch_pair: tiny_cranelift_conditional_branch == tiny_conditional_branch' "$manifest_doc" >/dev/null
    rg -n -F 'forbidden_codegen_status: implemented' "$manifest_doc" >/dev/null
    rg -n -F 'forbidden_default_enabled: true' "$manifest_doc" >/dev/null
    rg -n -F 'forbidden_production_route: cranelift' "$manifest_doc" >/dev/null
    rg -n -F 'forbidden_root_dependency: cranelift' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_experiment_dependency_manifest: compiler/experiments/cranelift/Cargo.toml' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_experiment_dependency_lockfile: compiler/experiments/cranelift/Cargo.lock' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_experiment_dependency_guard: guard-cranelift-dependency-beachhead' "$manifest_doc" >/dev/null
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
    if [ -n "$cranelift_recipe_wiring" ]; then
      echo "Phase 9 Step 12 allows only the Cranelift experiment manifest, inert backend surface, dependency beachhead, explicit backend suite, no-fixture regression guard, real return-int/local-binding/branch object smokes, and differential native smoke guards, found additional Cranelift recipes:"
      echo "$cranelift_recipe_wiring"
      exit 1
    fi
    cranelift_refs="$(rg -n -i -F 'cranelift' compiler src tests Cargo.toml Cargo.lock Makefile 2>/dev/null | rg -v '^compiler/CRANELIFT_EXPERIMENT_MANIFEST\.md:' | rg -v '^compiler/experiments/cranelift/' || true)"
    if [ -n "$cranelift_refs" ]; then
      echo "Phase 9 Step 1 must not add Cranelift implementation references:"
      echo "$cranelift_refs"
      exit 1
    fi
    echo "✅ Cranelift experiment manifest surface passed: dependency beachhead plus explicit backend suite, real return-int/local-binding object smokes, branch differential lane, disabled by default, and no production codegen exists yet."

guard-cranelift-backend-surface:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking Cranelift backend surface..."
    manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
    just guard-cranelift-experiment-manifest-surface
    rg -n -F 'CRANELIFT_EXPERIMENT_PHASE: phase9-mir-to-c-differential-entry' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_STATUS: mir_to_c_differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_CODEGEN_STATUS: return_int_local_binding_branch_differential_fixture_only' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_BACKEND_SURFACE_STATUS: differential_native_smoke' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_PRIMARY_ROUTE: mir_to_c' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_BACKEND_SURFACE_GUARD: guard-cranelift-backend-surface' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_RETURN_INT_NATIVE_GUARD: guard-cranelift-return-int-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_LOCAL_BINDING_NATIVE_GUARD: guard-cranelift-local-binding-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-local-binding-read-native-smoke' justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_BRANCH_NATIVE_GUARD: guard-cranelift-conditional-branch-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-branch-native-smoke' justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_DIFFERENTIAL_NATIVE_GUARD: guard-cranelift-mir-to-c-differential-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-differential-native-smoke' justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_BACKEND_SUITE_GUARD: guard-cranelift-experimental-backend-suite' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-experimental-backend-suite' justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_DEPENDENCY_BEACHHEAD_GUARD: guard-cranelift-dependency-beachhead' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-dependency-beachhead' justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_NO_FIXTURE_REGRESSION_GUARD: guard-cranelift-no-fixture-regression' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-no-fixture-regression' justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_IDENTITY_I32_NATIVE_GUARD: guard-cranelift-identity-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-identity-i32-native-smoke' justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_POSITIVE_I32_BRANCH_NATIVE_GUARD: guard-cranelift-positive-i32-branch-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-positive-i32-branch-native-smoke' justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_INCREMENT_LOCAL_I32_NATIVE_GUARD: guard-cranelift-increment-local-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-increment-local-i32-native-smoke' justfile >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_CALL_HELPER_I32_NATIVE_GUARD: guard-cranelift-call-helper-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-call-helper-i32-native-smoke' justfile >/dev/null
    rg -n -F 'allowed_call_helper_i32_native_guard: guard-cranelift-call-helper-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_call_helper_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_call_helper_i32_object_artifact: build/guards/cranelift_call_helper_i32_native/tiny_cranelift_call_helper_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_EXTERN_CALL_I32_NATIVE_GUARD: guard-cranelift-extern-call-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-extern-call-i32-native-smoke' justfile >/dev/null
    rg -n -F 'allowed_extern_call_i32_native_guard: guard-cranelift-extern-call-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_call_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_call_i32_object_artifact: build/guards/cranelift_extern_call_i32_native/tiny_cranelift_extern_call_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_call_i32_host_symbol: tiny_host_add_one_i32' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_EXTERN_ADD_I32_NATIVE_GUARD: guard-cranelift-extern-add-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-extern-add-i32-native-smoke' justfile >/dev/null
    rg -n -F 'allowed_extern_add_i32_native_guard: guard-cranelift-extern-add-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_add_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_add_i32_object_artifact: build/guards/cranelift_extern_add_i32_native/tiny_cranelift_extern_add_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_add_i32_host_symbol: tiny_host_add_i32' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_EXTERN_PREDICATE_BRANCH_I32_NATIVE_GUARD: guard-cranelift-extern-predicate-branch-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-extern-predicate-branch-i32-native-smoke' justfile >/dev/null
    rg -n -F 'allowed_extern_predicate_branch_i32_native_guard: guard-cranelift-extern-predicate-branch-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_predicate_branch_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_predicate_branch_i32_object_artifact: build/guards/cranelift_extern_predicate_branch_i32_native/tiny_cranelift_extern_predicate_branch_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_extern_predicate_branch_i32_host_symbol: tiny_host_is_positive_i32' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_RETURN_INT_NATIVE_GUARD: guard-cranelift-mir-return-int-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-mir-return-int-native-smoke' justfile >/dev/null
    rg -n -F 'allowed_mir_return_int_native_guard: guard-cranelift-mir-return-int-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_return_int_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_return_int_object_artifact: build/guards/cranelift_mir_return_int_native/tiny_cranelift_mir_return_int.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_return_int_symbol: tiny_cranelift_mir_return_int' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_return_int_lowering_scaffold: TinyMirFunction' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_LOCAL_BINDING_READ_NATIVE_GUARD: guard-cranelift-mir-local-binding-read-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-mir-local-binding-read-native-smoke' justfile >/dev/null
    rg -n -F 'allowed_mir_local_binding_read_native_guard: guard-cranelift-mir-local-binding-read-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_local_binding_read_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_local_binding_read_object_artifact: build/guards/cranelift_mir_local_binding_read_native/tiny_cranelift_mir_local_binding_read.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_local_binding_read_symbol: tiny_cranelift_mir_local_binding_read' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_local_binding_read_lowering_scaffold: TinyMirStatement::LocalI32Set' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_CONDITIONAL_BRANCH_NATIVE_GUARD: guard-cranelift-mir-conditional-branch-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-mir-conditional-branch-native-smoke' justfile >/dev/null
    rg -n -F 'allowed_mir_conditional_branch_native_guard: guard-cranelift-mir-conditional-branch-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_conditional_branch_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_conditional_branch_object_artifact: build/guards/cranelift_mir_conditional_branch_native/tiny_cranelift_mir_conditional_branch.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_conditional_branch_symbol: tiny_cranelift_mir_conditional_branch' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_conditional_branch_lowering_scaffold: TinyMirTerminator::BranchI32Literal' "$manifest_doc" >/dev/null
    rg -n -F 'CRANELIFT_EXPERIMENT_ALLOWED_MIR_ADD_I32_NATIVE_GUARD: guard-cranelift-mir-add-i32-native-smoke' "$manifest_doc" justfile >/dev/null
    rg -n -F 'guard-cranelift-mir-add-i32-native-smoke' justfile >/dev/null
    rg -n -F 'allowed_mir_add_i32_native_guard: guard-cranelift-mir-add-i32-native-smoke' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_add_i32_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_add_i32_object_artifact: build/guards/cranelift_mir_add_i32_native/tiny_cranelift_mir_add_i32.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_add_i32_symbol: tiny_cranelift_mir_add_i32' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_mir_add_i32_lowering_scaffold: TinyMirTerminator::ReturnParamI32Add' "$manifest_doc" >/dev/null
    rg -n -F 'No production Cranelift codegen entry point exists yet.' "$manifest_doc" >/dev/null
    rg -n -F 'The only allowed real Cranelift codegen entry point is compiler/experiments/cranelift/src/main.rs for return-int, local-binding/read, conditional-branch, and add-i32 object emission.' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_return_int_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_return_int_object_artifact: build/guards/cranelift_return_int_native/tiny_cranelift_return_int.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_local_binding_codegen_entry: compiler/experiments/cranelift/src/main.rs' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_local_binding_object_artifact: build/guards/cranelift_local_binding_native/tiny_cranelift_local_binding_read.o' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_experiment_dependency_manifest: compiler/experiments/cranelift/Cargo.toml' "$manifest_doc" >/dev/null
    rg -n -F 'allowed_experiment_dependency_lockfile: compiler/experiments/cranelift/Cargo.lock' "$manifest_doc" >/dev/null
    rg -n -F 'forbidden_root_dependency: cranelift' "$manifest_doc" >/dev/null
    rg -n -F 'No production compiler path may route to Cranelift yet.' "$manifest_doc" >/dev/null
    rg -n -F 'forbidden_production_backend_codegen_entry: cranelift_codegen' "$manifest_doc" >/dev/null
    rg -n -F 'forbidden_production_route: cranelift' "$manifest_doc" >/dev/null
    unexpected_cranelift_recipes="$(just --list | rg -n -i '(^|[[:space:]])(guard-.*cranelift|cranelift[-_:])' | rg -v -F 'guard-cranelift-experiment-manifest-surface' | rg -v -F 'guard-cranelift-backend-surface' | rg -v -F 'guard-cranelift-dependency-beachhead' | rg -v -F 'guard-cranelift-experimental-backend-suite' | rg -v -F 'guard-cranelift-no-fixture-regression' | rg -v -F 'guard-cranelift-return-int-native-smoke' | rg -v -F 'guard-cranelift-local-binding-native-smoke' | rg -v -F 'guard-cranelift-local-binding-read-native-smoke' | rg -v -F 'guard-cranelift-conditional-branch-native-smoke' | rg -v -F 'guard-cranelift-branch-native-smoke' | rg -v -F 'guard-cranelift-identity-i32-native-smoke' | rg -v -F 'guard-cranelift-mir-to-c-differential-native-smoke' | rg -v -F 'guard-cranelift-differential-native-smoke' || true)"
    unexpected_cranelift_recipes="$(printf '%s\n' "$unexpected_cranelift_recipes" | rg -v -F 'guard-cranelift-add-i32-native-smoke' || true)"
    unexpected_cranelift_recipes="$(printf '%s\n' "$unexpected_cranelift_recipes" | rg -v -F 'guard-cranelift-positive-i32-branch-native-smoke' || true)"
    unexpected_cranelift_recipes="$(printf '%s\n' "$unexpected_cranelift_recipes" | rg -v -F 'guard-cranelift-increment-local-i32-native-smoke' || true)"
    unexpected_cranelift_recipes="$(printf '%s\n' "$unexpected_cranelift_recipes" | rg -v -F 'guard-cranelift-call-helper-i32-native-smoke' || true)"
    unexpected_cranelift_recipes="$(printf '%s\n' "$unexpected_cranelift_recipes" | rg -v -F 'guard-cranelift-extern-call-i32-native-smoke' || true)"
    unexpected_cranelift_recipes="$(printf '%s\n' "$unexpected_cranelift_recipes" | rg -v -F 'guard-cranelift-extern-add-i32-native-smoke' || true)"
    unexpected_cranelift_recipes="$(printf '%s\n' "$unexpected_cranelift_recipes" | rg -v -F 'guard-cranelift-extern-predicate-branch-i32-native-smoke' || true)"
    unexpected_cranelift_recipes="$(printf '%s\n' "$unexpected_cranelift_recipes" | rg -v -F 'guard-cranelift-mir-return-int-native-smoke' || true)"
    unexpected_cranelift_recipes="$(printf '%s\n' "$unexpected_cranelift_recipes" | rg -v -F 'guard-cranelift-mir-local-binding-read-native-smoke' || true)"
    unexpected_cranelift_recipes="$(printf '%s\n' "$unexpected_cranelift_recipes" | rg -v -F 'guard-cranelift-mir-conditional-branch-native-smoke' || true)"
    unexpected_cranelift_recipes="$(printf '%s\n' "$unexpected_cranelift_recipes" | rg -v -F 'guard-cranelift-mir-add-i32-native-smoke' || true)"
    if [ -n "$unexpected_cranelift_recipes" ]; then
      echo "Cranelift backend surface allows no extra Cranelift recipes beyond the Step 10 return-int/local-binding object smoke lanes yet:"
      echo "$unexpected_cranelift_recipes"
      exit 1
    fi
    implementation_refs="$(rg -n -i 'cranelift_codegen|cranelift_emit|cranelift_compile|CraneliftBackend' compiler src tests Cargo.toml Cargo.lock Makefile 2>/dev/null | rg -v '^compiler/CRANELIFT_EXPERIMENT_MANIFEST\.md:' | rg -v '^compiler/experiments/cranelift/' || true)"
    if [ -n "$implementation_refs" ]; then
      echo "Cranelift backend surface must not include production codegen, root deps, or non-experiment implementation refs yet:"
      echo "$implementation_refs"
      exit 1
    fi
    echo "✅ Cranelift backend surface passed: dependency beachhead, explicit backend suite, real return-int/local-binding object smokes, and branch differential smoke are allowed, but production codegen/routes are still absent."

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

guard-cranelift-differential-native-smoke:
    just guard-cranelift-mir-to-c-differential-native-smoke

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
    rg -n -F 'real_cranelift_object_smoke: return_int' "$manifest_doc" >/dev/null
    rg -n -F 'real_cranelift_object_smoke: local_binding_read' "$manifest_doc" >/dev/null
    rg -n -F 'real_cranelift_object_smoke: conditional_branch' "$manifest_doc" >/dev/null
    rg -n -F 'real_cranelift_object_smoke: mir_return_int' "$manifest_doc" >/dev/null
    rg -n -F 'real_cranelift_object_smoke: mir_local_binding_read' "$manifest_doc" >/dev/null
    rg -n -F 'real_cranelift_object_smoke: mir_conditional_branch' "$manifest_doc" >/dev/null
    rg -n -F 'real_cranelift_object_smoke: mir_add_i32' "$manifest_doc" >/dev/null
    rg -n -F 'oracle_backend: mir_to_c' "$manifest_doc" >/dev/null
    rg -n -F 'production_route: mir_to_c' "$manifest_doc" >/dev/null
    rg -n -F 'identity-i32-object' justfile >/dev/null
    cranelift_native_bodies="$(sed -n '/^guard-cranelift-return-int-native-smoke:/,/^guard-cranelift-local-binding-read-native-smoke:/p' justfile; sed -n '/^guard-cranelift-local-binding-native-smoke:/,/^guard-cranelift-conditional-branch-native-smoke:/p' justfile; sed -n '/^guard-cranelift-conditional-branch-native-smoke:/,/^guard-cranelift-mir-to-c-differential-native-smoke:/p' justfile; sed -n '/^guard-cranelift-identity-i32-native-smoke:/,/^guard-cranelift-differential-native-smoke:/p' justfile)"
    forbidden_fixture_defs="$(printf '%s\n' "$cranelift_native_bodies" | rg -n -F 'int tiny_cranelift_' || true)"
    if [ -n "$forbidden_fixture_defs" ]; then
      echo "Migrated Cranelift native smoke lanes must not regress to C fixture function definitions:"
      echo "$forbidden_fixture_defs"
      exit 1
    fi
    printf '%s\n' "$cranelift_native_bodies" | rg -n -F 'return-int-object' >/dev/null
    printf '%s\n' "$cranelift_native_bodies" | rg -n -F 'local-binding-read-object' >/dev/null
    printf '%s\n' "$cranelift_native_bodies" | rg -n -F 'conditional-branch-object' >/dev/null
    printf '%s\n' "$cranelift_native_bodies" | rg -n -F 'add-i32-object' >/dev/null
    printf '%s\n' "$cranelift_native_bodies" | rg -n -F 'positive-i32-branch-object' >/dev/null
    printf '%s\n' "$cranelift_native_bodies" | rg -n -F 'increment-local-i32-object' >/dev/null
    printf '%s\n' "$cranelift_native_bodies" | rg -n -F 'call-helper-i32-object' >/dev/null
    printf '%s\n' "$cranelift_native_bodies" | rg -n -F 'extern-call-i32-object' >/dev/null
    printf '%s\n' "$cranelift_native_bodies" | rg -n -F 'extern-add-i32-object' >/dev/null
    printf '%s\n' "$cranelift_native_bodies" | rg -n -F 'extern-predicate-branch-i32-object' >/dev/null
    printf '%s\n' "$cranelift_native_bodies" | rg -n -F 'mir-return-int-object' >/dev/null
    printf '%s\n' "$cranelift_native_bodies" | rg -n -F 'mir-local-binding-read-object' >/dev/null
    printf '%s\n' "$cranelift_native_bodies" | rg -n -F 'mir-conditional-branch-object' >/dev/null
    printf '%s\n' "$cranelift_native_bodies" | rg -n -F 'mir-add-i32-object' >/dev/null
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
    just guard-cranelift-return-int-native-smoke
    just guard-cranelift-local-binding-read-native-smoke
    just guard-cranelift-conditional-branch-native-smoke
    just guard-cranelift-identity-i32-native-smoke
    just guard-cranelift-add-i32-native-smoke
    just guard-cranelift-positive-i32-branch-native-smoke
    just guard-cranelift-increment-local-i32-native-smoke
    just guard-cranelift-call-helper-i32-native-smoke
    just guard-cranelift-extern-call-i32-native-smoke
    just guard-cranelift-extern-add-i32-native-smoke
    just guard-cranelift-extern-predicate-branch-i32-native-smoke
    just guard-cranelift-mir-return-int-native-smoke
    just guard-cranelift-mir-local-binding-read-native-smoke
    just guard-cranelift-mir-conditional-branch-native-smoke
    just guard-cranelift-mir-add-i32-native-smoke
    just guard-cranelift-mir-to-c-differential-native-smoke
    echo "✅ Explicit experimental Cranelift backend suite passed."
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
