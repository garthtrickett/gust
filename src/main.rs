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
        type CustomNode[connCtx] struct {
            SessionID: int,
            Active: int
        }

        // Branded custom function accepting a native Arena reference [1, 3]
        func updateNode(ctx: &Arena, node: Index[CustomNode, ctx]) {
            ctx[node].SessionID = 100;
        }

        func main() {
            mut connCtx := os.Arena.New();
            defer connCtx.Free();
            
            mut node: Index[CustomNode, connCtx] := os.ArenaAlloc(connCtx);
            connCtx[node].SessionID = 42;
            
            // Pass the allocator and index into the function [3]
            updateNode(connCtx, node);
            
            os.LogInt(connCtx[node].SessionID); // Prints 100 natively!

            // Validate built-in str view operations [1]
            mut msg := \"Hello Arena\";
            os.LogStr(msg);                  // Prints 'Hello Arena'
            os.LogInt(len(msg));             // Prints 11 (native length)
        }
    ";

    let unsafe_program_source = "
        type CustomNode[connCtx] struct {
            SessionID: int,
            Active: int
        }

        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut payload := os.MockPayload();
            mut result := payload as &CustomNode[ctx];
            
            // Move payload, which invalidates the backing memory of the view! [1]
            mut movedPayload := move payload;
            
            // Compile Error: Variable 'result' cannot be used because its backing origin 'payload' has been moved or invalidated! [1]
            os.LogInt(result.Val.SessionID);
        }
    ";

    println!("====================================================");
    println!("PASS 1: SAFE PROGRAM COMPILATION TEST (MODULAR FUNCTIONS)");
    println!("====================================================");
    run_compile_pass(safe_program_source, "gust_output.c");

    println!("\n====================================================");
    println!("PASS 2: UNSAFE PROGRAM COMPILATION TEST (ESCAPE ANALYSIS)");
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
            let codegen = Codegen::new(
                checker.variable_types,
                checker.struct_registry,
                checker.function_registry,
            );
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
