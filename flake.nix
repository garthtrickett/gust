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
          '';
        };
      });
    };
}
