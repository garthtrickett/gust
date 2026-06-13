use gust_lexer::codegen::Codegen;
use gust_lexer::lexer::Lexer;
use gust_lexer::parser::Parser;
use gust_lexer::typechecker::TypeChecker;
use std::env;
use std::fs::File;
use std::io::Write;

#[derive(Debug, PartialEq, Eq)]
enum CliMode {
    Compile,
    Test,
    DumpAst,
    DumpTypes,
}

struct CliArgs {
    mode: CliMode,
    input_file: Option<String>,
    output_file: Option<String>,
}

fn parse_cli_args(args: &[String]) -> Result<CliArgs, String> {
    if args.len() < 2 {
        return Err("No arguments provided".to_string());
    }

    if args[1] == "--test" {
        return Ok(CliArgs {
            mode: CliMode::Test,
            input_file: None,
            output_file: None,
        });
    }

    if args[1] == "--dump-ast" {
        if args.len() < 3 {
            return Err("Missing input file for --dump-ast".to_string());
        }
        return Ok(CliArgs {
            mode: CliMode::DumpAst,
            input_file: Some(args[2].clone()),
            output_file: None,
        });
    }

    if args[1] == "--dump-types" {
        if args.len() < 3 {
            return Err("Missing input file for --dump-types".to_string());
        }
        return Ok(CliArgs {
            mode: CliMode::DumpTypes,
            input_file: Some(args[2].clone()),
            output_file: None,
        });
    }

    if args[1].starts_with('-') {
        return Err(format!("Unknown flag: {}", args[1]));
    }

    let input_file = args[1].clone();
    let output_file = if args.len() > 2 {
        Some(args[2].clone())
    } else {
        Some("gust_output.c".to_string())
    };

    Ok(CliArgs {
        mode: CliMode::Compile,
        input_file: Some(input_file),
        output_file,
    })
}

fn main() {
    gust_lexer::init_logging();
    let args: Vec<String> = env::args().collect();

    let cli_args = match parse_cli_args(&args) {
        Ok(args) => args,
        Err(err) => {
            eprintln!("Error: {}", err);
            print_usage();
            std::process::exit(1);
        }
    };

    match cli_args.mode {
        CliMode::Test => {
            run_self_tests();
        }
        CliMode::Compile => {
            let input_filename = cli_args.input_file.as_ref().unwrap();
            let output_filename = cli_args.output_file.as_ref().unwrap();
            println!("Compiling Gust program '{}'...", input_filename);
            run_compile_pass_file(input_filename, output_filename, false, false);
        }
        CliMode::DumpAst => {
            let input_filename = cli_args.input_file.as_ref().unwrap();
            run_compile_pass_file(input_filename, "", true, false);
        }
        CliMode::DumpTypes => {
            let input_filename = cli_args.input_file.as_ref().unwrap();
            run_compile_pass_file(input_filename, "", false, true);
        }
    }
}

fn print_usage() {
    println!("Usage:");
    println!("  cargo run -- <input_file.gst> [output_file.c]   Compile a Gust file");
    println!("  cargo run -- --dump-ast <input_file.gst>        Dump entry module AST and exit");
    println!("  cargo run -- --dump-types <input_file.gst>      Dump type database and exit");
    println!("  cargo run -- --test                             Run compiler self-tests");
}

fn run_compile_pass_file(input_filename: &str, output_filename: &str, dump_ast: bool, dump_types: bool) {
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;

    match resolver.resolve(std::path::Path::new(input_filename), &fs_impl) {
        Ok((order, modules)) => {
            if dump_ast
                && let Some(entry_path) = order.last()
                    && let Some(module) = modules.get(entry_path) {
                        let ast_str = module.program.serialize(0);
                        print!("{}", ast_str);
                        std::process::exit(0);
                    }

            let mut checker = TypeChecker::new();
            let mut check_error = None;
            for path in &order {
                if let Some(module) = modules.get(path) {
                    let stem = path.file_stem().unwrap().to_str().unwrap();
                    let is_entry = path == order.last().unwrap();
                    let prefix = if is_entry {
                        "".to_string()
                    } else {
                        format!("{}__", stem)
                    };
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
                            s.span().start.offset == span.start.offset
                                && s.span().end.offset == span.end.offset
                        });
                        if found {
                            source_code = module.source.clone();
                            break;
                        }
                    }
                    if source_code.is_empty()
                        && let Some(module) = modules.values().next()
                    {
                        source_code = module.source.clone();
                    }
                }
                let diagnostic = gust_lexer::typechecker::format_diagnostic(&source_code, &err);
                eprintln!("{}", diagnostic);
                std::process::exit(1);
            }

            if dump_types {
                let types_str = checker.serialize();
                print!("{}", types_str);
                std::process::exit(0);
            }

            let codegen = Codegen::new(
                checker.variable_types,
                checker.struct_registry,
                checker.function_registry,
                checker.enum_registry,
                checker.resolved_names,
                checker.resolved_types,
            );
            let mut modules_for_codegen = Vec::new();
            for path in &order {
                if let Some(module) = modules.get(path) {
                    modules_for_codegen.push((path.clone(), module.program.clone()));
                }
            }
            let c_output = codegen.generate(&modules_for_codegen);

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
            let modules_for_codegen = vec![(std::path::PathBuf::from("input.gst"), program)];
            let c_output = codegen.generate(&modules_for_codegen);

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
