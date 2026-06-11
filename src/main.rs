use gust_lexer::codegen::Codegen;
use gust_lexer::lexer::Lexer;
use gust_lexer::parser::Parser;
use gust_lexer::typechecker::TypeChecker;
use std::env;
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

    println!("Compiling Gust program '{}'...", input_filename);
    run_compile_pass_file(input_filename, output_filename);
}

fn print_usage() {
    println!("Usage:");
    println!("  cargo run -- <input_file.gst> [output_file.c]   Compile a Gust file");
    println!("  cargo run -- --test                             Run compiler self-tests");
}

fn run_compile_pass_file(input_filename: &str, output_filename: &str) {
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    
    match resolver.resolve(std::path::Path::new(input_filename), &fs_impl) { 
        Ok((order, mut modules)) => {
            let mut unified_statements = Vec::new();
            for path in &order { 
                if let Some(module) = modules.get_mut(path) {
                    unified_statements.append(&mut module.program.statements);
                }
            }

            let program = gust_lexer::ast::Program {
                statements: unified_statements,
                span: gust_lexer::token::Span::dummy(),
            };

            let mut checker = TypeChecker::new();
            let mut check_error = None;
            for path in &order { 
                if let Some(module) = modules.get(path) {
                    let stem = path.file_stem().unwrap().to_str().unwrap();
                    let is_entry = path == order.last().unwrap();
                    let prefix = if is_entry { "".to_string() } else { format!("{}__", stem) };
                    if let Err(err) = checker.check_module(&module.program, &prefix) { 
                        check_error = Some(err);
                        break;
                    }
                }
            }

            if let Some(err) = check_error { 
                let mut source_code = String::new();
                if let Some(span) = err.span {
                    for module in modules.values() {
                        let found = module.program.statements.iter().any(|s| {
                            s.span().start.offset == span.start.offset && s.span().end.offset == span.end.offset
                        });
                        if found {
                            source_code = module.source.clone();
                            break;
                        }
                    }
                    if source_code.is_empty()
                        && let Some(module) = modules.values().next() {
                            source_code = module.source.clone();
                        }
                }
                let diagnostic = gust_lexer::typechecker::format_diagnostic(&source_code, &err);
                eprintln!("{}", diagnostic);
                std::process::exit(1);
            }

            let codegen = Codegen::new(
                checker.variable_types,
                checker.struct_registry,
                checker.function_registry,
                checker.enum_registry,
                checker.resolved_names,
                checker.resolved_types,
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
            let diagnostic = gust_lexer::typechecker::format_diagnostic("", &err);
            eprintln!("{}", diagnostic);
            std::process::exit(1);
        }
    }
}

fn run_compile_pass(source_code: &str, output_filename: &str) {
    let lexer = Lexer::new(source_code);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();

    if !parser.errors.is_empty() {
        for err in &parser.errors {
            let diagnostic = gust_lexer::typechecker::format_diagnostic(source_code, err);
            eprintln!("{}", diagnostic);
        }
        std::process::exit(1);
    }

    let mut checker = TypeChecker::new();
    match checker.check_program(&program) {
        Ok(_) => {
            let codegen = Codegen::new(
                checker.variable_types,
                checker.struct_registry,
                checker.function_registry,
                checker.enum_registry,
                checker.resolved_names,
                checker.resolved_types,
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
            let diagnostic = gust_lexer::typechecker::format_diagnostic(source_code, &err);
            eprintln!("{}", diagnostic);
            std::process::exit(1);
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
            
            if result.Ok {
                os.LogInt(result.Val.SessionID);
            }
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
