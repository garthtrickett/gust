pub mod ast;
pub mod codegen;
pub mod lexer;
pub mod parser;
pub mod token;
pub mod typechecker;

use crate::codegen::Codegen;
use crate::lexer::Lexer;
use crate::parser::Parser;
use crate::typechecker::TypeChecker;
use std::fs::File;
use std::io::Write;

fn main() {
    let safe_program_source = "
        func main() {
            mut connCtx := os.Arena.New();
            defer connCtx.Free();
            
            mut node: Index[connCtx] := os.ArenaAlloc(connCtx);
            connCtx[node].SessionID = 42;
            
            unsafe {
                // AddressOf and casting inside an unsafe block
                mut rawPtr: *int := &connCtx[node].SessionID as *int;
                *rawPtr = 99; // Dereference and mutate memory
            }
            
            os.LogInt(connCtx[node].SessionID); // Prints 99 natively!
        }
    ";

    let unsafe_program_source = "
        func main() {
            mut connCtx := os.Arena.New();
            defer connCtx.Free();
            
            mut node: Index[connCtx] := os.ArenaAlloc(connCtx);
            mut rawPtr: *int := &connCtx[node].SessionID as *int;
            
            // Compile Error: Pointer dereferencing strictly prohibited outside unsafe blocks
            *rawPtr = 99;
        }
    ";

    println!("====================================================");
    println!("PASS 1: SAFE PROGRAM COMPILATION TEST (UNSAFE ESCAPE HATCH)");
    println!("====================================================");
    run_compile_pass(safe_program_source, "gust_output.c");

    println!("\n====================================================");
    println!("PASS 2: UNSAFE PROGRAM COMPILATION TEST (DEREF OUTSIDE UNSAFE)");
    println!("====================================================");
    run_compile_pass(unsafe_program_source, "gust_unsafe.c");
}

fn run_compile_pass(source_code: &str, output_filename: &str) {
    let lexer = Lexer::new(source_code);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();

    let mut checker = TypeChecker::new();
    match checker.check_program(&program) {
        Ok(_) => {
            let codegen = Codegen::new(checker.variable_types);
            let c_output = codegen.generate(&program);

            println!("✅ Type Checking Successful! Program is type-safe.");
            println!("Writing transpiled source code to '{}'...", output_filename);

            let mut file = File::create(output_filename).expect("Could not create output file");
            file.write_all(c_output.as_bytes())
                .expect("Could not write code to disk");
            println!("✅ Code written successfully to '{}'!", output_filename);
        }
        Err(err) => {
            println!(
                "❌ Type Checking Failed! Compiler successfully rejected unsafe code:\n{}",
                err
            );
        }
    }
}
