#!/usr/bin/env bash
# c.sh - Main file-aggregation execution driver

# Determine the project root directory
PROJECT_ROOT="."
if [ ! -d "src" ] && [ -d "../src" ]; then
    PROJECT_ROOT=".."
fi

# Load configuration from concat.config if it exists, otherwise use defaults
CONFIG_FILE="$PROJECT_ROOT/concat.config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # Fallback Defaults
    OUTPUT_FILE="a.txt"
    ROOT_CONFIG_FILES=("flake.nix" "Cargo.toml" "GEMINI.md" "Makefile")
    TARGET_DIRS=("src" "compiler" "tests")
    FILE_EXTENSIONS=("gst" "c" "h")
    EXCLUDE_PATTERNS=()
fi

# Clear the output file if it already exists
>"$PROJECT_ROOT/$OUTPUT_FILE"

# Append root configuration files if they exist and are allowed
for config in "${ROOT_CONFIG_FILES[@]}"; do
    # Check if the config file itself matches any exclude patterns
    is_excluded=0
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$config" == $pattern ]]; then
            is_excluded=1
            break
        fi
    done

    if [ $is_excluded -eq 0 ]; then
        file_path="$PROJECT_ROOT/$config"
        if [ -f "$file_path" ]; then
            echo "--- START OF FILE $config ---" >>"$PROJECT_ROOT/$OUTPUT_FILE"
            cat "$file_path" >>"$PROJECT_ROOT/$OUTPUT_FILE"
            echo -e "\n--- END OF FILE $config ---\n" >>"$PROJECT_ROOT/$OUTPUT_FILE"
        fi
    fi
done

# Build directory search paths relative to PROJECT_ROOT
search_dirs=()
for dir in "${TARGET_DIRS[@]}"; do
    dir_path="$PROJECT_ROOT/$dir"
    if [ -d "$dir_path" ]; then
        search_dirs+=("$dir_path")
    fi
done

# If directories exist, perform search and aggregation
if [ ${#search_dirs[@]} -gt 0 ] && [ ${#FILE_EXTENSIONS[@]} -gt 0 ]; then
    # Build extension name filters
    name_args=()
    for ext in "${FILE_EXTENSIONS[@]}"; do
        if [ ${#name_args[@]} -gt 0 ]; then
            name_args+=("-o")
        fi
        name_args+=("-name" "*.$ext")
    done

    # Build exclude arguments
    exclude_args=()
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        exclude_args+=("-not" "-path" "*/$pattern" "-not" "-name" "$pattern")
    done

    # Execute find and append matching files
    while IFS= read -r file; do
        display_path="${file#$PROJECT_ROOT/}"

        echo "--- START OF FILE $display_path ---" >>"$PROJECT_ROOT/$OUTPUT_FILE"
        cat "$file" >>"$PROJECT_ROOT/$OUTPUT_FILE"
        echo -e "\n--- END OF FILE $display_path ---\n" >>"$PROJECT_ROOT/$OUTPUT_FILE"
    done < <(find "${search_dirs[@]}" -type f \( "${name_args[@]}" \) "${exclude_args[@]}" 2>/dev/null | sort)
fi

# Append the current Step 5.1 raw pointer classification report when available.
# This keeps a.txt self-contained for follow-up migration patches without making
# the report a failing gate.
if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step51_raw_pointer_classified:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step51_raw_pointer_classified ---"
        (cd "$PROJECT_ROOT" && make report_step51_raw_pointer_classified)
        echo "--- END OF REPORT make report_step51_raw_pointer_classified ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step51_raw_pointer_safe_code_candidates:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step51_raw_pointer_safe_code_candidates ---"
        (cd "$PROJECT_ROOT" && make report_step51_raw_pointer_safe_code_candidates)
        echo "--- END OF REPORT make report_step51_raw_pointer_safe_code_candidates ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step51_address_escapes_focused:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step51_address_escapes_focused ---"
        (cd "$PROJECT_ROOT" && make report_step51_address_escapes_focused)
        echo "--- END OF REPORT make report_step51_address_escapes_focused ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step51_ffi_calls:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step51_ffi_calls ---"
        (cd "$PROJECT_ROOT" && make report_step51_ffi_calls)
        echo "--- END OF REPORT make report_step51_ffi_calls ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step51_ffi_focused:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step51_ffi_focused ---"
        (cd "$PROJECT_ROOT" && make report_step51_ffi_focused)
        echo "--- END OF REPORT make report_step51_ffi_focused ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step51_phase_b_wrapping_status:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step51_phase_b_wrapping_status ---"
        (cd "$PROJECT_ROOT" && make report_step51_phase_b_wrapping_status)
        echo "--- END OF REPORT make report_step51_phase_b_wrapping_status ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step51_phase_c_basic_unsafe_status:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step51_phase_c_basic_unsafe_status ---"
        (cd "$PROJECT_ROOT" && make report_step51_phase_c_basic_unsafe_status)
        echo "--- END OF REPORT make report_step51_phase_c_basic_unsafe_status ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step51_phase_d_ffi_status:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step51_phase_d_ffi_status ---"
        (cd "$PROJECT_ROOT" && make report_step51_phase_d_ffi_status)
        echo "--- END OF REPORT make report_step51_phase_d_ffi_status ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step51_phase_e_address_escape_status:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step51_phase_e_address_escape_status ---"
        (cd "$PROJECT_ROOT" && make report_step51_phase_e_address_escape_status)
        echo "--- END OF REPORT make report_step51_phase_e_address_escape_status ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step51_phase_f_non_laundering_status:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step51_phase_f_non_laundering_status ---"
        (cd "$PROJECT_ROOT" && make report_step51_phase_f_non_laundering_status)
        echo "--- END OF REPORT make report_step51_phase_f_non_laundering_status ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step51_deferred_unsafe_semantics_status:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step51_deferred_unsafe_semantics_status ---"
        (cd "$PROJECT_ROOT" && make report_step51_deferred_unsafe_semantics_status)
        echo "--- END OF REPORT make report_step51_deferred_unsafe_semantics_status ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step51_status_matrix:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step51_status_matrix ---"
        (cd "$PROJECT_ROOT" && make report_step51_status_matrix)
        echo "--- END OF REPORT make report_step51_status_matrix ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step52_linear_resource_inventory:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step52_linear_resource_inventory ---"
        (cd "$PROJECT_ROOT" && make report_step52_linear_resource_inventory)
        echo "--- END OF REPORT make report_step52_linear_resource_inventory ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step52_linear_resource_focused:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step52_linear_resource_focused ---"
        (cd "$PROJECT_ROOT" && make report_step52_linear_resource_focused)
        echo "--- END OF REPORT make report_step52_linear_resource_focused ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step52_phase_a_status:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step52_phase_a_status ---"
        (cd "$PROJECT_ROOT" && make report_step52_phase_a_status)
        echo "--- END OF REPORT make report_step52_phase_a_status ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step52_phase_b_destructor_status:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step52_phase_b_destructor_status ---"
        (cd "$PROJECT_ROOT" && make report_step52_phase_b_destructor_status)
        echo "--- END OF REPORT make report_step52_phase_b_destructor_status ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step52_phase_c_resource_registry_status:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step52_phase_c_resource_registry_status ---"
        (cd "$PROJECT_ROOT" && make report_step52_phase_c_resource_registry_status)
        echo "--- END OF REPORT make report_step52_phase_c_resource_registry_status ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step52_phase_d_transfer_status:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step52_phase_d_transfer_status ---"
        (cd "$PROJECT_ROOT" && make report_step52_phase_d_transfer_status)
        echo "--- END OF REPORT make report_step52_phase_d_transfer_status ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step52_phase_e_enforcement_preconditions_status:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step52_phase_e_enforcement_preconditions_status ---"
        (cd "$PROJECT_ROOT" && make report_step52_phase_e_enforcement_preconditions_status)
        echo "--- END OF REPORT make report_step52_phase_e_enforcement_preconditions_status ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step52_phase_f_closure_status:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step52_phase_f_closure_status ---"
        (cd "$PROJECT_ROOT" && make report_step52_phase_f_closure_status)
        echo "--- END OF REPORT make report_step52_phase_f_closure_status ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step52_status_matrix:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step52_status_matrix ---"
        (cd "$PROJECT_ROOT" && make report_step52_status_matrix)
        echo "--- END OF REPORT make report_step52_status_matrix ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^guard_step52_report_only_lanes_not_in_test:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make guard_step52_report_only_lanes_not_in_test ---"
        (cd "$PROJECT_ROOT" && make guard_step52_report_only_lanes_not_in_test)
        echo "--- END OF REPORT make guard_step52_report_only_lanes_not_in_test ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^guard_step52_no_post_closure_report_churn:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make guard_step52_no_post_closure_report_churn ---"
        (cd "$PROJECT_ROOT" && make guard_step52_no_post_closure_report_churn)
        echo "--- END OF REPORT make guard_step52_no_post_closure_report_churn ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

if [ -f "$PROJECT_ROOT/Makefile" ] && grep -q '^report_step52_final_validation:' "$PROJECT_ROOT/Makefile"; then
    {
        echo "--- START OF REPORT make report_step52_final_validation ---"
        (cd "$PROJECT_ROOT" && make report_step52_final_validation)
        echo "--- END OF REPORT make report_step52_final_validation ---"
        echo
    } >>"$PROJECT_ROOT/$OUTPUT_FILE" 2>&1 || true
fi

echo "✅ Aggregated target project files into $PROJECT_ROOT/$OUTPUT_FILE"
