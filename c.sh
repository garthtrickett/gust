#!/usr/bin/env bash

OUTPUT_FILE="a.txt"

# Clear the output file if it already exists
>"$OUTPUT_FILE"

# Determine the project root directory
PROJECT_ROOT="."
if [ ! -d "src" ] && [ -d "../src" ]; then
    PROJECT_ROOT=".."
fi

# Append root configuration files if they exist
CONFIG_FILES=("flake.nix" "Cargo.toml" "GEMINI.md" "apply_changes.py" "bridge.sh" "flake.nix")
for config in "${CONFIG_FILES[@]}"; do
    file_path="$PROJECT_ROOT/$config"
    if [ -f "$file_path" ]; then
        echo "--- START OF FILE $config ---" >>"$OUTPUT_FILE"
        cat "$file_path" >>"$OUTPUT_FILE"
        echo -e "\n--- END OF FILE $config ---\n" >>"$OUTPUT_FILE"
    fi
done

# Dynamically find and append all Rust files inside src/ and tests/
if [ -d "$PROJECT_ROOT/src" ] || [ -d "$PROJECT_ROOT/tests" ] || [ -d "$PROJECT_ROOT/compiler" ]; then
    # find targets both directories, filtering for files ending in .rs, sorted for consistency
    while IFS= read -r file; do
        # Clean up the output boundary path representation
        display_path="${file#$PROJECT_ROOT/}"

        echo "--- START OF FILE $display_path ---" >>"$OUTPUT_FILE"
        cat "$file" >>"$OUTPUT_FILE"
        echo -e "\n--- END OF FILE $display_path ---\n" >>"$OUTPUT_FILE"
    done < <(find "$PROJECT_ROOT/src" "$PROJECT_ROOT/tests" "$PROJECT_ROOT/compiler" -type f \( -name "*.rs" -o -name "*.gst" \) 2>/dev/null | sort)
fi

echo "✅ Aggregated all project configuration and Rust files into $OUTPUT_FILE"
