use gust_lexer::codegen::Codegen;
use gust_lexer::lexer::Lexer;
use gust_lexer::parser::Parser;
use gust_lexer::typechecker::TypeChecker;
use std::env;
use std::fs;
use std::fs::File;
use std::io::Write;

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        print_usage();
        return;
    }

    if args[1] == "--test" {
        run_self_tests();
        return;
    }

    let input_filename = &args[1];
    let output_filename = if args.len() > 2 {
        &args[2]
    } else {
        "gust_output.c"
    };

    match fs::read_to_string(input_filename) {
        Ok(source_code) => {
            println!("Compiling Gust program '{}'...", input_filename);
            run_compile_pass(&source_code, output_filename);
        }
        Err(err) => {
            println!("❌ Failed to read input file '{}': {}", input_filename, err);
        }
    }
}

fn print_usage() {
    println!("Usage:");
    println!("  cargo run -- <input_file.gst> [output_file.c]   Compile a Gust file");
    println!("  cargo run -- --test                             Run compiler self-tests");
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
            println!(
                "Writing transpiled C source code to '{}'...",
                output_filename
            );

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

fn run_self_tests() {
    let safe_program_source = "
        type CustomNode[connCtx] struct {
            SessionID: int,
            Active: int
        }

        func updateNode(ctx: &Arena, node: Index[CustomNode, ctx]) {
            ctx[node].SessionID = 100;
        }

        func main() {
            mut connCtx := os.Arena.New();
            defer connCtx.Free();
            
            mut node: Index[CustomNode, connCtx] := os.ArenaAlloc(connCtx);
            connCtx[node].SessionID = 42;
            
            updateNode(connCtx, node);
            
            os.LogInt(connCtx[node].SessionID);

            mut msg := \"Hello Arena\";
            os.LogStr(msg);
            os.LogInt(len(msg));
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
            
            mut movedPayload := move payload;
            
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
