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
    rg -n -F 'SUCCESS: mir to c entry smoke' compiler/mir_to_c_entry_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir to c function shell smoke' compiler/mir_to_c_function_shell_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir to c return int literal smoke' compiler/mir_to_c_return_int_literal_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir to c block jump smoke' compiler/mir_to_c_block_jump_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir to c conditional branch smoke' compiler/mir_to_c_conditional_branch_smoke_test_entry.gst >/dev/null
    rg -n -F 'guard-mir-to-c-entry-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-function-shell-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-return-int-literal-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-return-int-literal-native-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-block-jump-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-block-jump-native-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-conditional-branch-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-to-c-conditional-branch-native-smoke' justfile >/dev/null
    rg -n -F 'compiler/mir_to_c_entry_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_to_c_function_shell_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_to_c_return_int_literal_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_to_c_block_jump_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_to_c_conditional_branch_smoke_test_entry.gst' justfile >/dev/null
    unexpected_mir_to_c_refs="$(rg -n -F 'mir_to_c_' compiler/*.gst | rg -v 'compiler/mir.gst:|compiler/mir_to_c_entry_smoke_test_entry.gst:|compiler/mir_to_c_function_shell_smoke_test_entry.gst:|compiler/mir_to_c_return_int_literal_smoke_test_entry.gst:|compiler/mir_to_c_local_binding_read_smoke_test_entry.gst:|compiler/mir_to_c_block_jump_smoke_test_entry.gst:|compiler/mir_to_c_conditional_branch_smoke_test_entry.gst:' || true)"
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
    rg -n -F 'MIR_FEATURE_MIGRATION_PHASE: tiny-registry' "$harness_doc" >/dev/null
    rg -n -F 'MIR_FEATURE_MIGRATION_NO_FEATURES_MIGRATED: false' "$harness_doc" >/dev/null
    rg -n -F 'MIR_FEATURE_MIGRATION_REGISTRY: compiler/MIR_FEATURE_MIGRATION_REGISTRY.md' "$harness_doc" >/dev/null
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
    rg -n -F 'compiler/mir_feature_return_int_preservation_source.gst' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-feature-return-int-preservation' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-lower-return-int-literal-smoke' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-return-int-literal-smoke' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-return-int-literal-native-smoke' "$harness_doc" "$registry_doc" justfile >/dev/null
    rg -n -F 'native executable exits with status `1`' "$harness_doc" >/dev/null
    rg -n -F 'expected_behavior: native executable exits with status 1' "$registry_doc" >/dev/null
    just guard-mir-feature-registry-surface
    echo "✅ MIR feature migration harness surface guard passed."

guard-mir-feature-migration-registry:
    just guard-mir-feature-registry-surface

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
    rg -n -F 'MIR_FEATURE_MIGRATION_REGISTRY_PHASE: tiny-registry' "$registry_doc" >/dev/null
    rg -n -F 'MIR_FEATURE_MIGRATION_REGISTRY_ENTRY_COUNT: 1' "$registry_doc" >/dev/null
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
    rg -n -F 'compiler/mir_feature_return_int_preservation_source.gst' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-feature-return-int-preservation' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-lower-return-int-literal-smoke' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-return-int-literal-smoke' "$registry_doc" justfile >/dev/null
    rg -n -F 'guard-mir-to-c-return-int-literal-native-smoke' "$registry_doc" justfile >/dev/null
    echo "✅ MIR feature migration registry surface guard passed."

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

guard-mir-feature-migration-suite:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔒 Checking MIR feature migration suite..."
    just guard-mir-feature-harness-surface
    just guard-mir-feature-migration-registry
    just guard-mir-feature-return-int-preservation
    just guard-mir-feature-local-binding-read-preservation
    just guard-mir-feature-if-else-return-int-preservation
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
    rg -n -F 'tiny_shell' compiler/mir.gst compiler/mir_lower_tiny_function_fixture_smoke_test_entry.gst compiler/mir_lower_function_shell_smoke_test_entry.gst >/dev/null
    rg -n -F 'tiny_return_int' compiler/mir.gst compiler/mir_lower_return_int_literal_smoke_test_entry.gst >/dev/null
    rg -n -F 'tiny_block_jump' compiler/mir.gst compiler/mir_lower_block_jump_smoke_test_entry.gst >/dev/null
    rg -n -F 'tiny_conditional_branch' compiler/mir.gst compiler/mir_lower_conditional_branch_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirTerminator.ReturnVoid' compiler/mir_lower_function_shell_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirTerminator.Return' compiler/mir_lower_return_int_literal_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirTerminator.Jump' compiler/mir_lower_block_jump_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirTerminator.Branch' compiler/mir_lower_conditional_branch_smoke_test_entry.gst >/dev/null
    rg -n -F 'MirValue.IntLiteral' compiler/mir_lower_return_int_literal_smoke_test_entry.gst >/dev/null
    rg -n -F 'return_value.IntLiteral.val != 1' compiler/mir_lower_return_int_literal_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir lower tiny function fixture entry' compiler/mir_lower_tiny_function_fixture_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir lower function shell smoke' compiler/mir_lower_function_shell_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir lower return int literal smoke' compiler/mir_lower_return_int_literal_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir lower block jump smoke' compiler/mir_lower_block_jump_smoke_test_entry.gst >/dev/null
    rg -n -F 'SUCCESS: mir lower conditional branch smoke' compiler/mir_lower_conditional_branch_smoke_test_entry.gst >/dev/null
    rg -n -F 'compiler/mir_lower_tiny_function_fixture_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_lower_function_shell_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_lower_return_int_literal_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_lower_block_jump_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'compiler/mir_lower_conditional_branch_smoke_test_entry.gst' justfile >/dev/null
    rg -n -F 'guard-mir-lower-tiny-function-fixture-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-lower-function-shell-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-lower-return-int-literal-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-lower-block-jump-smoke' justfile >/dev/null
    rg -n -F 'guard-mir-lower-conditional-branch-smoke' justfile >/dev/null
    unexpected_lower_refs="$(rg -n -F 'mir_lower_' compiler/*.gst | rg -v 'compiler/mir.gst:|compiler/mir_lower_tiny_function_fixture_smoke_test_entry.gst:|compiler/mir_lower_function_shell_smoke_test_entry.gst:|compiler/mir_lower_return_int_literal_smoke_test_entry.gst:|compiler/mir_lower_local_binding_read_smoke_test_entry.gst:|compiler/mir_lower_block_jump_smoke_test_entry.gst:|compiler/mir_lower_conditional_branch_smoke_test_entry.gst:|compiler/mir_to_c_entry_smoke_test_entry.gst:|compiler/mir_to_c_function_shell_smoke_test_entry.gst:|compiler/mir_to_c_return_int_literal_smoke_test_entry.gst:|compiler/mir_to_c_local_binding_read_smoke_test_entry.gst:|compiler/mir_to_c_block_jump_smoke_test_entry.gst:|compiler/mir_to_c_conditional_branch_smoke_test_entry.gst:' || true)"
    if [ -n "$unexpected_lower_refs" ]; then
      echo "Unexpected MIR lowering reference outside fixture-only files:"
      echo "$unexpected_lower_refs"
      exit 1
    fi
    backend_refs="$(rg -n -F 'Cranelift' compiler/mir.gst compiler/mir_lower_tiny_function_fixture_smoke_test_entry.gst compiler/mir_lower_function_shell_smoke_test_entry.gst compiler/mir_lower_return_int_literal_smoke_test_entry.gst compiler/mir_lower_local_binding_read_smoke_test_entry.gst compiler/mir_lower_block_jump_smoke_test_entry.gst compiler/mir_lower_conditional_branch_smoke_test_entry.gst || true)"
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
