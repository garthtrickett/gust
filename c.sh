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
CONFIG_FILES=("flake.nix" "Cargo.toml" "GEMINI.md" "apply_changes.py" "bridge.sh")
for config in "${CONFIG_FILES[@]}"; do
    file_path="$PROJECT_ROOT/$config"
    if [ -f "$file_path" ]; then
        echo "--- START OF FILE $config ---" >>"$OUTPUT_FILE"
        cat "$file_path" >>"$OUTPUT_FILE"
        echo -e "\n--- END OF FILE $config ---\n" >>"$OUTPUT_FILE"
    fi
done

# Dynamically find and append all Rust, Gust, C, and Header files inside src/, tests/, and compiler/
if [ -d "$PROJECT_ROOT/src" ] || [ -d "$PROJECT_ROOT/tests" ] || [ -d "$PROJECT_ROOT/compiler" ]; then
    # Find targets, filtering for files ending in .rs, .gst, .c, or .h, sorted for consistency
    while IFS= read -r file; do
        # Clean up the output boundary path representation
        display_path="${file#$PROJECT_ROOT/}"

        echo "--- START OF FILE $display_path ---" >>"$OUTPUT_FILE"
        cat "$file" >>"$OUTPUT_FILE"
        echo -e "\n--- END OF FILE $display_path ---\n" >>"$OUTPUT_FILE"
    done < <(find "$PROJECT_ROOT/src" "$PROJECT_ROOT/tests" "$PROJECT_ROOT/compiler" -type f \( -name "*.rs" -o -name "*.gst" -o -name "*.c" -o -name "*.h" \) 2>/dev/null | sort)
fi

echo "✅ Aggregated all project configuration, Rust, Gust, and C/Header files into $OUTPUT_FILE"
