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
        checker.enum_registry,
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

// =====================================================================
// === THREE RE-DRAFTED PRESSURE-TEST PROGRAMS ===
// =====================================================================

#[test]
fn test_e2e_program_a_zero_copy_network_processor() {
    let source = "
        type Packet struct {
            ProtocolID: int,
            SeqNum: int,
            Length: int
        }

        func main() {
            mut payload := os.MockPayload();
            
            // Cast the raw byte slice dynamically to a struct reference
            mut result := payload as &Packet;
            
            if result.Ok {
                os.LogInt(result.Val.ProtocolID);
            } else {
                os.LogInt(0);
            }
        }
    ";
    run_e2e_test(source, "42");
}

#[test]
fn test_e2e_program_b_safe_arena_cyclic_graph() {
    let source = "
        type GraphNode[ctx] struct {
            Value: int,
            Next: Index[GraphNode, ctx]
        }

        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut nodeA: Index[GraphNode, ctx] := os.ArenaAlloc(ctx);
            mut nodeB: Index[GraphNode, ctx] := os.ArenaAlloc(ctx);
            mut nodeC: Index[GraphNode, ctx] := os.ArenaAlloc(ctx);

            ctx[nodeA].Value = 10;
            ctx[nodeB].Value = 20;
            ctx[nodeC].Value = 30;

            ctx[nodeA].Next = nodeB;
            ctx[nodeB].Next = nodeC;
            ctx[nodeC].Next = nodeA;

            mut curr := nodeA;
            mut count := 0;
            while count < 6 {
                os.LogInt(ctx[curr].Value);
                curr = ctx[curr].Next;
                count = count + 1;
            }
        }
    ";
    run_e2e_test(source, "10\n20\n30\n10\n20\n30");
}

#[test]
fn test_e2e_program_c_universal_ownership_operators() {
    let source = "
        type DataWrapper struct {
            Value: int
        }

        func main() {
            mut wrapper: DataWrapper;
            wrapper.Value = 100;
            
            mut movedWrapper := move wrapper;
            os.LogInt(movedWrapper.Value);
            
            mut payload := os.MockPayload();
            mut taken := take payload;
            
            os.LogInt(taken[0]);
            os.LogInt(len(taken));
        }
    ";
    run_e2e_test(source, "100\n42\n1024");
}

// === NEW E2E TESTS FOR THE NATIVE VECTOR & HASHMAP IMPLEMENTATION ===

#[test]
fn test_e2e_native_collections_evaluation() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut vec: Vector[int, ctx] := os.VectorNew(ctx);
            vec.Push(10);
            vec.Push(20);
            vec.Push(30);

            os.LogInt(len(vec));
            os.LogInt(vec[0]);
            os.LogInt(vec[1]);
            os.LogInt(vec[2]);

            mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
            map.Insert(100, 42);
            map.Insert(200, 84);

            os.LogInt(len(map));
            os.LogInt(map[100]);
            os.LogInt(map[200]);

            // Mutable Assignment (L-value Subscription checks)
            map[100] = 999;
            os.LogInt(map[100]);
        }
    ";
    run_e2e_test(source, "3\n10\n20\n30\n2\n42\n84\n999");
}

// === NEW E2E TESTS FOR ALGEBRAIC DATA TYPES & PATTERN MATCHING ===

#[test]
fn test_e2e_adt_match_evaluation() {
    let source = "
        type Shape enum {
            Circle { radius: int },
            Rectangle { width: int, height: int },
            Point
        }

        func process(shape: Shape) int {
            match shape {
                Circle => {
                    return shape.Circle.radius;
                }
                Rectangle => {
                    return shape.Rectangle.width + shape.Rectangle.height;
                }
                Point => {
                    return 123;
                }
            }
        }

        func main() {
            mut s1: Shape;
            s1.tag = 0;
            s1.Circle.radius = 42;

            mut s2: Shape;
            s2.tag = 1;
            s2.Rectangle.width = 10;
            s2.Rectangle.height = 20;

            mut s3: Shape;
            s3.tag = 2;

            os.LogInt(process(s1));
            os.LogInt(process(s2));
            os.LogInt(process(s3));
        }
    ";
    run_e2e_test(source, "42\n30\n123");
}

// === NEW E2E TESTS FOR THE NATIVE FILE I/O IMPLEMENTATION ===

#[test]
fn test_e2e_file_io_evaluation() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut path := \"test_output_file.txt\";
            mut contents := \"Hello from Gust Compiler File I/O!\";
            
            mut success := os.WriteFile(path, contents);
            os.LogInt(success);

            mut read_back := os.ReadFile(ctx, path);
            os.LogStr(read_back);
            os.LogInt(len(read_back));
        }
    ";
    run_e2e_test(source, "1\nHello from Gust Compiler File I/O!\n34");
}

#[test]
fn test_e2e_fallible_lookup_evaluation() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
            map.Insert(100, 42);
            map.Insert(200, 84);

            // Existing key
            mut lookup1 := map.Get(100);
            os.LogInt(lookup1.Ok);
            if lookup1.Ok {
                os.LogInt(lookup1.Val);
            }

            // Non-existent key
            mut lookup2 := map.Get(300);
            os.LogInt(lookup2.Ok);
            if lookup2.Ok {
                os.LogInt(lookup2.Val);
            } else {
                os.LogInt(0);
            }
        }
    ";
    run_e2e_test(source, "1\n42\n0\n0");
}

#[test]
fn test_e2e_is_valid_invariant_validation() {
    let source = "
        type StatusPacket struct {
            ID: int,
            Active: byte,
            Verified: byte
        }

        func main() {
            mut payload := os.MockPayload();
            mut result := payload as &StatusPacket;

            if result.Ok {
                result.Val.ID = 101;
                result.Val.Active = 1;
                result.Val.Verified = 0;

                // Case A: Valid flags
                mut ok1 := StatusPacket_IsValid(&result.Val);
                os.LogInt(ok1);

                // Case B: Corrupted flag
                result.Val.Active = 5;
                mut ok2 := StatusPacket_IsValid(&result.Val);
                os.LogInt(ok2);
            } else {
                os.LogInt(999);
            }
        }
    ";
    run_e2e_test(source, "1\n0");
}

#[test]
fn test_e2e_enum_indirection_pattern() {
    let source = "
        type LargePayload struct {
            x: int,
            y: int,
            z: int
        }

        type MyEnum[ctx] enum {
            VariantA { val: Index[LargePayload, ctx] },
            VariantB
        }

        func process(e: MyEnum[ctx], ctx: &Arena) int {
            match e {
                VariantA => {
                    mut index := e.VariantA.val;
                    return ctx[index].x + ctx[index].y + ctx[index].z;
                }
                VariantB => {
                    return 0;
                }
            }
        }

        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut p: Index[LargePayload, ctx] := os.ArenaAlloc(ctx);
            ctx[p].x = 10;
            ctx[p].y = 20;
            ctx[p].z = 30;

            mut e: MyEnum[ctx];
            e.tag = 0;
            e.VariantA.val = p;

            mut res := process(e, ctx);
            os.LogInt(res);
        }
    ";
    run_e2e_test(source, "60");
}

#[test]
fn test_e2e_universal_move_semantics_monomorphized() {
    let source = "
        type Wrapper[T] struct {
            val: T
        }

        func main() {
            mut w1: Wrapper[int];
            w1.val = 100;

            mut w2 := move w1;
            os.LogInt(w1.val); // POD copy - remains valid
            os.LogInt(w2.val);
        }
    ";
    run_e2e_test(source, "100\n100");
}
