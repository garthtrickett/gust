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
          ];

          shellHook = ''
            echo "🦀 Gust Lexer Development Environment Loaded"
            echo "Cargo: $(cargo --version)"
            echo "Rustc: $(rustc --version)"
            
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

            gcf() {
              cargo clippy --fix --allow-dirty
            }

            echo "💡 Available Commands:"
            echo "  gtl             - Run all tests with debug logging directed to to.log"
            echo "  gt-one <test_name> - Run a specific test with debug logging directed to to.log"
            echo "  gcf             - Run 'cargo clippy --fix --allow-dirty'"
          '';
        };
      });
    };
}
