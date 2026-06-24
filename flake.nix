{
  description = "Minimalist Rust development environment for the Gust Lexer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f (import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      }));
    in
    {
      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            bashInteractive
            pkg-config
            # Explicitly provide the Nix C compiler/linker toolchain
            stdenv.cc
          ];

          buildInputs = with pkgs; [
            # Rust Compiler Toolchain
            cargo
            rustc
            rust-analyzer # Highly recommended for LSP/IDE support
            rustfmt
            clippy
            python3
            ripgrep
            gdb

            # Tree-sitter & Node Toolchain
            tree-sitter
            nodejs
          ];

          shellHook = ''
            echo "🦀 Gust Lexer Development Environment Loaded"
            echo "Cargo: $(cargo --version)"
            echo "Rustc: $(rustc --version)"
            echo "Tree-sitter: $(tree-sitter --version)"
            
            # Export CC to point directly to the Nix-provided linker
            export CC="${pkgs.stdenv.cc}/bin/cc"

            # Custom test runners
            gtl() {
              RUST_LOG=debug cargo test test -- --nocapture --test-threads=1 > to.log 2>&1
              echo "📝 All tests run. Output written to to.log"
            }

            gt-one() {
              if [ -z "$1" ]; then
                echo "❌ Error: Please provide a test name (e.g., gt-one test_self_hosted_import_scanner)"
                return 1
              fi
              RUST_LOG=debug cargo test "$1" -- --nocapture > to.log 2>&1
              echo "📝 Test '$1' run. Output written to to.log"
            }

            # Run a single positive or negative Gust test and pipe all compiler logs + runtime output to to.log
            gt-one-gst() {
              if [ -z "$1" ]; then
                echo "❌ Error: Please provide a test path (e.g., gt-one-gst tests/e2e_collections_methods.gst)"
                return 1
              fi

              # Force make to recognize any compiler changes by touching the entrypoint and rebuilding
              if [ -f compiler/test_runner_entry.gst ]; then
                touch compiler/test_runner_entry.gst
              fi
              make gust >/dev/null 2>&1

              TEST_PATH="$1"
              TEST_STEM=$(basename "''${TEST_PATH}" .gst)
              mkdir -p build

              # Clear and initialize log
              echo "=== [1/3] COMPILING GUST TO C ===" > to.log
              
              # Run the compiler. Capture stdout/stderr (which contain compile-time traces/emojis)
              ./gust "''${TEST_PATH}" > build/temp_output.log 2>&1
              COMP_STATUS=$?
              cat build/temp_output.log >> to.log

              # Check if this is a negative test (filenames containing 'rejected' or 'violation')
              if [[ "''${TEST_PATH}" == *"rejected"* || "''${TEST_PATH}" == *"violation"* ]]; then
                if [ ''${COMP_STATUS} -ne 0 ]; then
                  echo "✅ Negative test caught compilation failure successfully! See to.log for error."
                  return 0
                else
                  echo "❌ FAIL: Expected negative test to fail compilation, but it succeeded."
                  return 1
                fi
              fi

              if [ ''${COMP_STATUS} -ne 0 ]; then
                echo "❌ Gust compilation failed! See to.log for diagnostic errors."
                return ''${COMP_STATUS}
              fi

              # Filter out structural log emojis to output clean transpiled C code
              grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" build/temp_output.log > build/''${TEST_STEM}.c

              # Combine with runtime and compile C binary
              echo -e "\n=== [2/3] COMPILING NATIVE C EXECUTABLE ===" >> to.log
              cat src/runtime.c build/''${TEST_STEM}.c > build/''${TEST_STEM}_final.c
              cc -O2 -Wall -pthread -Isrc build/''${TEST_STEM}_final.c -o build/''${TEST_STEM}_bin >> to.log 2>&1
              C_STATUS=$?

              if [ ''${C_STATUS} -ne 0 ]; then
                echo "❌ Native C compilation failed! See to.log for compiler errors."
                return ''${C_STATUS}
              fi

              # Run the compiled binary
              echo -e "\n=== [3/3] RUNNING COMPILED BINARY ===" >> to.log
              ./build/''${TEST_STEM}_bin >> to.log 2>&1
              RUN_STATUS=$?

              if [ ''${RUN_STATUS} -ne 0 ]; then
                echo "❌ Runtime execution failed! See to.log for panic/segfault traces."
                return ''${RUN_STATUS}
              fi

              echo "📝 Test '$1' executed successfully. Output written to to.log"
            }

            gcf() {
              cargo clippy --fix --allow-dirty
            }

            echo "💡 Available Commands:"
            echo "  gtl             - Run all Rust tests with debug logging directed to to.log"
            echo "  gt-one <name>   - Run a specific Rust test with debug logging directed to to.log"
            echo "  gt-one-gst <f>  - Run a self-hosted .gst test (compiles, builds, runs) to to.log"
            echo "  gcf             - Run 'cargo clippy --fix --allow-dirty'"
          '';
        };
      });
    };
}
