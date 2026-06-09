#!/usr/bin/env bash

OUTPUT_FILE="a.txt"

# Clear the output file if it already exists
>"$OUTPUT_FILE"

# Define the list of files to aggregate
FILES=(
    "flake.nix"
    "Cargo.toml"
    "src/token.rs"
    "src/lexer.rs"
    "src/ast.rs"
    "src/parser.rs"
    "src/typechecker.rs"
    "src/codegen.rs"
    "src/main.rs"
    "tests/compile_tests.rs"
    "src/lib.rs"
)

# Append each file with clear boundaries
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "--- START OF FILE $file ---" >>"$OUTPUT_FILE"
        cat "$file" >>"$OUTPUT_FILE"
        echo -e "\n--- END OF FILE $file ---\n" >>"$OUTPUT_FILE"
    # Fallback to check the parent directory (in case flake.nix is there)
    elif [ -f "../$file" ]; then
        echo "--- START OF FILE ../$file ---" >>"$OUTPUT_FILE"
        cat "../$file" >>"$OUTPUT_FILE"
        echo -e "\n--- END OF FILE ../$file ---\n" >>"$OUTPUT_FILE"
    fi
done

echo "✅ Aggregated all project files into $OUTPUT_FILE"
