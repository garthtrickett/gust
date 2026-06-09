use std::env;
use std::fs;
use std::process::Command;
use std::sync::atomic::{AtomicUsize, Ordering};

use gust_lexer::codegen::Codegen;
use gust_lexer::lexer::Lexer;
use gust_lexer::parser::Parser;
use gust_lexer::typechecker::TypeChecker;

static TEST_COUNTER: AtomicUsize = AtomicUsize::new(0);

fn run_e2e_test(source: &str, expected_output: &str) {
    // 1. Compile the input Gust program
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();

    let mut checker = TypeChecker::new();
    let check_result = checker.check_program(&program);
    assert!(
        check_result.is_ok(),
        "Typechecking failed: {:?}",
        check_result.err()
    );

    let codegen = Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
    );
    let c_code = codegen.generate(&program);

    // 2. Write the transpiled C code to a temporary file
    let temp_dir = env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let count = TEST_COUNTER.fetch_add(1, Ordering::SeqCst);

    let c_filename = format!("gust_test_{:?}_{}_{}.c", thread_id, process_id, count);
    let bin_filename = format!("gust_test_{:?}_{}_{}.bin", thread_id, process_id, count);

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    fs::write(&c_path, &c_code).expect("Failed to write temporary C file");

    // 3. Invoke a system C compiler to compile it
    let compile_status = Command::new("cc")
        .arg(&c_path)
        .arg("-o")
        .arg(&bin_path)
        .status();

    let compile_success = match compile_status {
        Ok(status) => status.success(),
        Err(e) => {
            let _ = fs::remove_file(&c_path);
            panic!(
                "Failed to invoke system C compiler 'cc'. Is gcc/clang/cc installed? Error: {:?}",
                e
            );
        }
    };

    if !compile_success {
        let _ = fs::remove_file(&c_path);
        let _ = fs::remove_file(&bin_path);
        panic!("Compilation of the transpiled C code failed.");
    }

    // 4. Run the compiled binary and capture its standard output
    let run_output = Command::new(&bin_path).output();

    // Clean up temporary files immediately
    let _ = fs::remove_file(&c_path);
    let _ = fs::remove_file(&bin_path);

    let output = match run_output {
        Ok(out) => out,
        Err(e) => {
            panic!("Failed to execute the compiled test binary. Error: {:?}", e);
        }
    };

    // 5. Assert that the program exited with status 0 and printed the expected output string
    assert!(
        output.status.success(),
        "Test binary exited with non-zero status code: {:?}",
        output.status.code()
    );

    let stdout_str = String::from_utf8(output.stdout).expect("Captured output is not valid UTF-8");

    // Diagnostic output if test fails
    if stdout_str.trim() != expected_output.trim() {
        println!("\n====================================================");
        println!("FAILING E2E TEST: DIAGNOSTIC LOGS");
        println!("====================================================");
        println!("--- GENERATED C CODE ---");
        println!("{}", c_code);
        println!("------------------------");
        println!("ACTUAL STDOUT OUTPUT: {:?}", stdout_str);
        println!("EXPECTED STDOUT OUTPUT: {:?}", expected_output);
        println!("====================================================\n");
    }

    assert_eq!(stdout_str.trim(), expected_output.trim());
}

#[test]
fn test_e2e_safe_branding() {
    let source = "
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
    run_e2e_test(source, "100\nHello Arena\n11");
}

#[test]
fn test_e2e_arithmetic_and_logic() {
    let source = "
        func main() {
            mut x := 10 + 20 * 2;
            os.LogInt(x);

            if x == 50 {
                os.LogInt(1);
            } else {
                os.LogInt(0);
            }
        }
    ";
    run_e2e_test(source, "50\n1");
}

#[test]
fn test_e2e_loops_and_mutation() {
    let source = "
        func main() {
            mut i := 0;
            while i < 5 {
                os.LogInt(i);
                i = i + 1;
            }
        }
    ";
    run_e2e_test(source, "0\n1\n2\n3\n4");
}

#[test]
fn test_e2e_mock_payload_slicing() {
    let source = "
        func main() {
            mut payload := os.MockPayload();
            os.LogInt(payload[0]);
            os.LogInt(len(payload));
        }
    ";
    run_e2e_test(source, "42\n1024");
}
