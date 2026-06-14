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
    gust_lexer::init_logging();
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
        checker.resolved_names,
        checker.resolved_types,
    );
    let modules_for_codegen = vec![(std::path::PathBuf::from("input.gst"), program)];
    let c_code = codegen.generate(&modules_for_codegen);

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

    // Provide real-time path and logging visibility to assist debugging if a test hangs
    println!("--- RUNNING E2E TEST WITH TEMP C PATH: {:?} ---", c_path);
    if env::var("GUST_DUMP_C").is_ok() {
        println!("--- C CODE START ---\n{}\n--- C CODE END ---", c_code);
    }

    // 3. Invoke a system C compiler to compile it
    let cc_compiler = env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let mut cmd = Command::new(&cc_compiler);
    cmd.arg(&c_path);
    if env::var("GUST_NO_SANITIZERS").is_err() {
        cmd.arg("-fsanitize=address,undefined");
    }
    let compile_output = cmd.arg("-o").arg(&bin_path).output();

    let compile_success = match compile_output {
        Ok(output) => {
            if !output.status.success() {
                println!("--- GCC Compilation Failed ---");
                println!("STDOUT:\n{}", String::from_utf8_lossy(&output.stdout));
                println!("STDERR:\n{}", String::from_utf8_lossy(&output.stderr));
            }
            (output.status.success(), output)
        }
        Err(e) => {
            let _ = fs::remove_file(&c_path);
            panic!(
                "Failed to invoke system C compiler '{}'. Is gcc/clang/cc installed? Error: {:?}",
                cc_compiler, e
            );
        }
    };

    if !compile_success.0 {
        let stderr_str = String::from_utf8_lossy(&compile_success.1.stderr);
        let _ = fs::remove_file(&c_path);
        let _ = fs::remove_file(&bin_path);
        panic!(
            "Compilation of the transpiled C code failed. STDERR:\n{}",
            stderr_str
        );
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
fn test_e2e_else_if_and_comparison_operators() {
    let source = "
        func check_value(x: int) int {
            if x <= 10 {
                return 1;
            } else if x >= 20 {
                return 2;
            } else {
                return 3;
            }
        }
        func main() {
            os.LogInt(check_value(5));
            os.LogInt(check_value(25));
            os.LogInt(check_value(15));
        }
    ";
    run_e2e_test(source, "1\n2\n3");
}

#[test]
fn test_e2e_rich_formatting_basic() {
    let source = "
        func main() {
            mut name := \"Gust\";
            mut version := 1;
            mut s := std.Format(\"Welcome to %s version %d!\", name, version);
            os.LogStr(s);
        }
    ";
    run_e2e_test(source, "Welcome to Gust version 1!");
}

#[test]
fn test_e2e_rich_formatting_bounds() {
    let source = "
        func main() {
            mut large_str := \"ThisIsALargeStringWithManyCharactersToTestThatOurCalculationsAreExtremelyRobustAndPreventAnyPotentialBufferOverflowInTranspiledC\";
            mut neg_num := 0 - 2147483648;
            mut max_num := 2147483647;
            mut s := std.Format(\"String: %s, Neg: %d, Max: %d\", large_str, neg_num, max_num);
            os.LogStr(s);
        }
    ";
    run_e2e_test(
        source,
        "String: ThisIsALargeStringWithManyCharactersToTestThatOurCalculationsAreExtremelyRobustAndPreventAnyPotentialBufferOverflowInTranspiledC, Neg: -2147483648, Max: 2147483647",
    );
}

#[test]
fn test_e2e_rich_formatting_in_loop() {
    let source = "
        func main() {
            mut i := 0;
            while i < 10 {
                mut s := std.Format(\"Index: %d\", i);
                os.LogStr(s);
                os.ScratchReset();
                i = i + 1;
            } 
        }
    ";
    run_e2e_test(
        source,
        "Index: 0\nIndex: 1\nIndex: 2\nIndex: 3\nIndex: 4\nIndex: 5\nIndex: 6\nIndex: 7\nIndex: 8\nIndex: 9",
    );
}

#[test]
fn test_e2e_bool_primitive() {
    let source = "
        type Status struct {
            ok: bool
        }
        func main() {
            mut b: bool := true;
            os.LogInt(b as int);
            
            b = false;
            os.LogInt(b as int);
            
            mut s: Status;
            s.ok = true;
            os.LogInt(s.ok as int);
        }
    ";
    run_e2e_test(source, "1\n0\n1");
}

#[test]
fn test_e2e_string_escape_sequences() {
    let source = "
        func main() {
            mut msg := \"line1\\nline2\\ttab\\\\backslash\\\"quote\";
            os.LogStr(msg);
        } 
    ";
    run_e2e_test(source, "line1\nline2\ttab\\backslash\"quote");
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

#[test]
fn test_e2e_adt_match_destructuring_evaluation() {
    let source = "
        type Shape enum {
            Circle { radius: int },
            Rectangle { width: int, height: int },
            Point
        }

        func process(shape: Shape) int {
            match shape {
                Circle { radius } => {
                    return radius;
                }
                Rectangle { width, height } => {
                    return width + height;
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

            mut path := \"test_e2e_file_io_evaluation_output.txt\";
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

#[test]
fn test_e2e_relaxed_monomorphized_pod_performance() {
    let source = "
        type Element[T] struct {
            val: T,
            id: int
        }

        func main() {
            mut el1: Element[int];
            el1.val = 42;
            el1.id = 101;

            // Since T is int, Element[int] propagates to a copyable POD!
            mut el2 := move el1; 

            // Verify both the moved-from and the moved-to structures remain fully readable and optimized in C
            os.LogInt(el1.id);
            os.LogInt(el1.val);
            os.LogInt(el2.id);
            os.LogInt(el2.val);
        }
    ";
    run_e2e_test(source, "101\n42\n101\n42");
}

#[test]
fn test_e2e_take_and_empty_reinitialization() {
    let source = "
        type Resource[T, ctx] struct {
            val: T,
            active: int
        }

        func swap_resources(ctx: &Arena, a: *Resource[str, ctx], b: *Resource[str, ctx]) {
            mut temp: Resource[str, ctx] := empty[Resource[str, ctx]];
            unsafe {
                temp = take *a;
                *a = take *b;
                *b = move temp;
            }
        }

        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut r1: Resource[str, ctx];
            r1.val = \"Hello\";
            r1.active = 1;

            mut r2: Resource[str, ctx];
            r2.val = \"World\";
            r2.active = 2;

            swap_resources(ctx, &r1, &r2);

            os.LogStr(r1.val);
            os.LogInt(r1.active);
            os.LogStr(r2.val);
            os.LogInt(r2.active);
        }
    ";
    run_e2e_test(source, "World\n2\nHello\n1");
}

#[test]
fn test_e2e_sentinel_null_protection() {
    let source = "
        type Node[ctx] struct {
            val: int,
            next: Index[Node, ctx]
        }

        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            // Allocate a node to occupy offset 0 of the Arena
            mut first: Index[Node, ctx] := os.ArenaAlloc(ctx);
            ctx[first].val = 999;

            // Create an uninitialized Node structure.
            // Its 'next' field should be initialized to the safe sentinel null (0xFFFFFFFF),
            // NOT the raw 0 (which would incorrectly reference the 'first' node!).
            mut empty_node: Node[ctx];

            // Perform sentinel null check: assert empty_node.next is equal to null (0xFFFFFFFF)
            if empty_node.next == null {
                os.LogInt(1); // 1 = True (Safe)
            } else {
                os.LogInt(0); // 0 = False (Unsafe, collided with first node)
            }
        }
    ";
    run_e2e_test(source, "1");
}

#[test]
fn test_e2e_namespaced_collections() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut v: std.Vector[int, ctx] := std.VectorNew(ctx);
            v.Push(111);
            v.Push(222);

            os.LogInt(len(v));
            os.LogInt(v[0]);
            os.LogInt(v[1]);

            mut m: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
            m.Insert(10, 888);
            m.Insert(20, 999);

            os.LogInt(len(m));
            os.LogInt(m[10]);
            os.LogInt(m[20]);
        }
    ";
    run_e2e_test(source, "2\n111\n222\n2\n888\n999");
}

#[test]
fn test_e2e_string_utilities_evaluation() {
    let source = "
        func main() {
            mut s := \"Hello World\";
            
            // Substring slice
            mut sub := std.str_slice(s, 0, 5);
            os.LogStr(sub);
            
            // Substring slice 2
            mut sub2 := std.str_slice(s, 6, 11);
            os.LogStr(sub2);

            // Equality checks
            if std.str_eq(sub, \"Hello\") {
                os.LogInt(1);
            } else {
                os.LogInt(0);
            }

            if std.str_eq(sub, sub2) {
                os.LogInt(1);
            } else {
                os.LogInt(0);
            }

            // Safe index byte retrieval
            mut b := std.str_byte_at(s, 6);
            os.LogInt(b as int);
        } 
    ";
    run_e2e_test(source, "Hello\nWorld\n1\n0\n87");
}

#[test]
fn test_e2e_pool_allocation_recycling() {
    let source = "
        type Node struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut pool: std.Pool[Node, ctx] := std.PoolNew(ctx);

            mut n1: Node;
            n1.val = 111;
            mut idx1 := pool.Alloc(n1);

            mut n2: Node;
            n2.val = 222;
            mut idx2 := pool.Alloc(n2);

            mut n3: Node;
            n3.val = 333;
            mut idx3 := pool.Alloc(n3);

            // Log first three indices and values to verify
            os.LogInt(idx1);
            os.LogInt(pool[idx1].val);
            os.LogInt(idx2);
            os.LogInt(pool[idx2].val);
            os.LogInt(idx3);
            os.LogInt(pool[idx3].val);

            // Free n1 and n3
            pool.Free(idx1);
            pool.Free(idx3);

            // Allocate a fourth node
            mut n4: Node;
            n4.val = 444;
            mut idx4 := pool.Alloc(n4);

            // idx4 should reuse index 2 (which was idx3) because standard stack-based freelist reclaims the last freed slot!
            os.LogInt(idx4);
            os.LogInt(pool[idx4].val);
        } 
    ";
    run_e2e_test(source, "0\n111\n1\n222\n2\n333\n2\n444");
}

#[test]
fn test_e2e_generational_arena_loop() {
    let source = "
        type Node[ctx] struct {
            val: int
        }

        func main() {
            mut current_ctx := os.Arena.New();
            defer current_ctx.Free();
            mut next_ctx := os.Arena.New();
            defer next_ctx.Free();

            mut survivor: Index[Node, current_ctx] := os.ArenaAlloc(current_ctx);
            current_ctx[survivor].val = 0;

            mut i := 0;
            while i < 1000 {
                mut temp: Index[Node, current_ctx] := os.ArenaAlloc(current_ctx);
                current_ctx[temp].val = i;

                mut cloned_survivor: Index[Node, next_ctx] := std.Clone(next_ctx, survivor);
                next_ctx[cloned_survivor].val = next_ctx[cloned_survivor].val + current_ctx[temp].val;

                std.GenerationalSwap(current_ctx, next_ctx);

                survivor = cloned_survivor;

                i = i + 1;
            }

            os.LogInt(current_ctx[survivor].val);
        }
    ";
    run_e2e_test(source, "499500");
}

#[test]
fn test_e2e_rc_reference_counting() {
    let source = "
        type Node struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut pool: std.Pool[std.RcNode[Node], ctx] := std.PoolNew(ctx);
            mut item: Node;
            item.val = 42;

            mut rc1: std.Rc[Node, ctx] := std.RcNew(&pool, item);
            os.LogInt(rc1.node_index);
            
            unsafe {
                mut val_ptr := rc1.Get();
                os.LogInt((*val_ptr).val);
            }

            mut rc2 := rc1.Clone();
            os.LogInt(rc2.node_index);
            
            rc1.Release();
            
            mut item2: Node;
            item2.val = 100;
            
            mut rc3: std.Rc[Node, ctx] := std.RcNew(&pool, item2);
            os.LogInt(rc3.node_index);
            
            rc2.Release();
            
            mut rc4: std.Rc[Node, ctx] := std.RcNew(&pool, item2);
            os.LogInt(rc4.node_index);
        }
    ";
    run_e2e_test(source, "0\n42\n0\n1\n0");
}

#[test]
fn test_e2e_graph_cyclic_relationship() {
    let source = "
        type Node struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut graph: std.Graph[Node, ctx] := std.GraphNew(ctx);
            
            mut item1: Node; item1.val = 10;
            mut item2: Node; item2.val = 20;
            mut item3: Node; item3.val = 30;

            mut n1 := graph.AddNode(item1);
            mut n2 := graph.AddNode(item2);
            mut n3 := graph.AddNode(item3);

            graph.AddEdge(n1, n2);
            graph.AddEdge(n2, n3);
            graph.AddEdge(n3, n1);

            mut curr := n1;
            mut i := 0;
            while i < 6 {
                unsafe {
                    mut val_ptr := graph.GetNode(curr);
                    os.LogInt((*val_ptr).val);
                }
                curr = graph.nodes[curr].edges[0];
                i = i + 1;
            }
        }
    ";
    run_e2e_test(source, "10\n20\n30\n10\n20\n30");
}

#[test]
fn test_e2e_lexical_scope_tree() {
    let source = "
        type SharedConfig struct {
            compiler_flag: int
        }
        type Scope[ctx] struct {
            parent: Index[Scope[ctx], ctx],
            variables: std.HashMap[str, int, ctx],
            config: std.Rc[SharedConfig, ctx]
        }

        func lookup_variable(pool: *std.Pool[Scope[ctx], ctx], scope_idx: Index[Scope[ctx], ctx], name: str) int {
            mut curr := scope_idx;
            while curr != null {
                unsafe {
                    mut lookup := (*pool)[curr].variables.Get(name);
                    if lookup.Ok {
                        return lookup.Val;
                    }
                    curr = (*pool)[curr].parent;
                }
            }
            return 0 - 1;
        }

        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut pool: std.Pool[Scope[ctx], ctx] := std.PoolNew(ctx);
            mut rc_pool: std.Pool[std.RcNode[SharedConfig], ctx] := std.PoolNew(ctx);

            mut config: SharedConfig;
            config.compiler_flag = 42;

            mut rc_conf: std.Rc[SharedConfig, ctx] := std.RcNew(&rc_pool, config);

            mut root: Scope[ctx];
            root.parent = null;
            root.variables = std.HashMapNew(ctx);
            root.variables.Insert(\"global_var\", 100);
            root.variables.Insert(\"shadowed_var\", 1);
            root.config = rc_conf.Clone();

            mut root_idx := pool.Alloc(root);

            mut child: Scope[ctx];
            child.parent = root_idx;
            child.variables = std.HashMapNew(ctx);
            child.variables.Insert(\"local_var\", 200);
            child.variables.Insert(\"shadowed_var\", 2);
            child.config = rc_conf.Clone();

            mut child_idx := pool.Alloc(child);

            os.LogInt(lookup_variable(&pool, root_idx, \"global_var\"));
            os.LogInt(lookup_variable(&pool, root_idx, \"shadowed_var\"));
            os.LogInt(lookup_variable(&pool, root_idx, \"local_var\"));

            os.LogInt(lookup_variable(&pool, child_idx, \"global_var\"));
            os.LogInt(lookup_variable(&pool, child_idx, \"shadowed_var\"));
            os.LogInt(lookup_variable(&pool, child_idx, \"local_var\"));

            unsafe {
                mut flag_ptr := child.config.Get();
                os.LogInt((*flag_ptr).compiler_flag);
            }

            child.config.Release();
            root.config.Release();
            rc_conf.Release();
        }
    ";
    run_e2e_test(source, "100\n1\n-1\n100\n2\n200\n42");
}

#[test]
fn test_e2e_multi_module_compilation() {
    use std::fs;
    let temp_dir = env::temp_dir().join("gust_test_e2e_multi");
    fs::create_dir_all(&temp_dir).unwrap();

    let main_path = temp_dir.join("app.gst");
    let lib_path = temp_dir.join("math_lib.gst");

    // Write app.gst (entry file)
    fs::write(
        &main_path,
        "import \"math_lib.gst\" as math;\nfunc main() {\n    mut res := math.add(10, 20);\n    os.LogInt(res);\n}",
    )
    .unwrap();

    // Write math_lib.gst (library file)
    fs::write(
        &lib_path,
        "func add(a: int, b: int) int {\n    return a + b;\n}",
    )
    .unwrap();

    // Resolve modules recursively
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let res = resolver.resolve(&main_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, mut modules) = res.unwrap();
    assert_eq!(order.len(), 2);

    // Namespaced typechecking
    let mut checker = TypeChecker::new();
    for path in &order {
        if let Some(module) = modules.get(path) {
            let stem = path.file_stem().unwrap().to_str().unwrap();
            let is_entry = path == order.last().unwrap();
            let prefix = if is_entry {
                "".to_string()
            } else {
                format!("{}__", stem)
            };
            let check_res = checker.check_module(&module.program, &prefix);
            assert!(
                check_res.is_ok(),
                "Typechecking failed on {:?}: {:?}",
                path,
                check_res.err()
            );
        }
    }

    // Group statements for codegen
    let mut modules_for_codegen = Vec::new();
    for path in &order {
        if let Some(module) = modules.get_mut(path) {
            modules_for_codegen.push((path.clone(), module.program.clone()));
        }
    }

    let codegen = Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
        checker.enum_registry,
        checker.resolved_names,
        checker.resolved_types,
    );
    let c_code = codegen.generate(&modules_for_codegen);

    // Compile and run C code
    let c_filename = "gust_e2e_multi_output.c";
    let bin_filename = "gust_e2e_multi_output.bin";
    let c_path = temp_dir.join(c_filename);
    let bin_path = temp_dir.join(bin_filename);

    fs::write(&c_path, &c_code).expect("Failed to write temporary C file");

    let cc_compiler = env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let mut cmd = Command::new(&cc_compiler);
    cmd.arg(&c_path);
    if env::var("GUST_NO_SANITIZERS").is_err() {
        cmd.arg("-fsanitize=address,undefined");
    }
    let compile_output = cmd
        .arg("-o")
        .arg(&bin_path)
        .output()
        .expect("Failed to run compiler command");

    assert!(
        compile_output.status.success(),
        "GCC compilation failed: {}",
        String::from_utf8_lossy(&compile_output.stderr)
    );

    let run_output = Command::new(&bin_path)
        .output()
        .expect("Failed to run output binary");

    // Clean up temporary files
    let _ = fs::remove_file(&c_path);
    let _ = fs::remove_file(&bin_path);
    let _ = fs::remove_file(&main_path);
    let _ = fs::remove_file(&lib_path);
    let _ = fs::remove_dir(temp_dir);

    assert!(run_output.status.success());
    let stdout_str = String::from_utf8(run_output.stdout).unwrap();
    assert_eq!(stdout_str.trim(), "30");
}

#[test]
fn test_e2e_thread_local_scratchpad() {
    let source = "
        func main() {
            mut p1 := os.ScratchAlloc(10);
            unsafe {
                *p1 = 42;
                os.LogInt(*p1 as int);
            }
            
            mut p2 := os.ScratchAlloc(20);
            unsafe {
                *p2 = 84;
                os.LogInt(*p2 as int);
            }
            
            os.ScratchReset();
            
            mut p3 := os.ScratchAlloc(10);
            unsafe {
                os.LogInt(*p3 as int);
            }
        }
    ";

    // Compile without GUST_DEBUG, so after reset, memory is not poisoned (retains 42)
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
        checker.resolved_names,
        checker.resolved_types,
    );
    let modules_for_codegen = vec![(std::path::PathBuf::from("input.gst"), program)];
    let c_code = codegen.generate(&modules_for_codegen);

    let temp_dir = env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let count = TEST_COUNTER.fetch_add(1, Ordering::SeqCst);

    let c_filename = format!(
        "gust_scratch_test_{:?}_{}_{}.c",
        thread_id, process_id, count
    );
    let bin_filename_ndebug = format!(
        "gust_scratch_test_ndebug_{:?}_{}_{}.bin",
        thread_id, process_id, count
    );
    let bin_filename_debug = format!(
        "gust_scratch_test_debug_{:?}_{}_{}.bin",
        thread_id, process_id, count
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path_ndebug = temp_dir.join(&bin_filename_ndebug);
    let bin_path_debug = temp_dir.join(&bin_filename_debug);

    fs::write(&c_path, &c_code).expect("Failed to write temporary C file");

    let cc_compiler = env::var("CC").unwrap_or_else(|_| "cc".to_string());

    // Compile NDEBUG version
    let mut cmd_ndebug = Command::new(&cc_compiler);
    cmd_ndebug.arg(&c_path);
    if env::var("GUST_NO_SANITIZERS").is_err() {
        cmd_ndebug.arg("-fsanitize=address,undefined");
    }
    let compile_ndebug = cmd_ndebug
        .arg("-o")
        .arg(&bin_path_ndebug)
        .output()
        .expect("Compile failed");
    assert!(
        compile_ndebug.status.success(),
        "NDEBUG compile failed: {}",
        String::from_utf8_lossy(&compile_ndebug.stderr)
    );

    // Compile DEBUG version
    let mut cmd_debug = Command::new(&cc_compiler);
    cmd_debug.arg(&c_path).arg("-DGUST_DEBUG");
    if env::var("GUST_NO_SANITIZERS").is_err() {
        cmd_debug.arg("-fsanitize=address,undefined");
    }
    let compile_debug = cmd_debug
        .arg("-o")
        .arg(&bin_path_debug)
        .output()
        .expect("Compile failed");
    assert!(
        compile_debug.status.success(),
        "DEBUG compile failed: {}",
        String::from_utf8_lossy(&compile_debug.stderr)
    );

    // Run NDEBUG version: should output 42, 84, 42
    let run_ndebug = Command::new(&bin_path_ndebug).output().unwrap();
    let out_ndebug = String::from_utf8(run_ndebug.stdout).unwrap();
    assert_eq!(out_ndebug.trim(), "42\n84\n42");

    // Run DEBUG version: should output 42, 84, 165 (0xA5 memory poisoning)
    let run_debug = Command::new(&bin_path_debug).output().unwrap();
    let out_debug = String::from_utf8(run_debug.stdout).unwrap();
    assert_eq!(out_debug.trim(), "42\n84\n165");

    let _ = fs::remove_file(&c_path);
    let _ = fs::remove_file(&bin_path_ndebug);
    let _ = fs::remove_file(&bin_path_debug);
}

#[test]
fn test_e2e_directory_scanning() {
    let temp_dir_path = std::path::Path::new("temp_gust_e2e_dir");
    let _ = std::fs::remove_dir_all(temp_dir_path);
    std::fs::create_dir_all(temp_dir_path).unwrap();

    std::fs::write(temp_dir_path.join("file1.gst"), "func main() {}").unwrap();
    std::fs::write(temp_dir_path.join("file2.txt"), "plain text").unwrap();

    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut opt_dir := os.OpenDir(ctx, \"temp_gust_e2e_dir\");
            if opt_dir.Ok {
                mut d := opt_dir.Val;
                
                mut loop_active := 1;
                while loop_active == 1 {
                    mut opt_entry := os.ReadDir(ctx, d);
                    if opt_entry.Ok {
                        mut name := opt_entry.Val.name;
                        if len(name) > 4 {
                            mut ext := std.str_slice(name, len(name) - 4, len(name));
                            if std.str_eq(ext, \".gst\") {
                                os.LogStr(name);
                            }
                        }
                    } else {
                        loop_active = 0;
                    }
                }
                os.CloseDir(d);
            }
        }
    ";

    run_e2e_test(source, "file1.gst");

    let _ = std::fs::remove_dir_all(temp_dir_path);
}

#[test]
fn test_e2e_scratchpad_formatting_loop() {
    let source = "
        func main() {
            mut i := 0;
            while i < 5 {
                mut s_num := std.FormatInt(i);
                mut greeting := std.Concat(\"Num: \", s_num);
                os.LogStr(greeting);
                os.ScratchReset();
                i = i + 1;
            }
        }
    ";
    run_e2e_test(source, "Num: 0\nNum: 1\nNum: 2\nNum: 3\nNum: 4");
}

#[test]
fn test_e2e_mutex_concurrency() {
    let source = "
        type Counter struct {
            count: int
        }
        type ThreadArg[ctx] struct {
            mutex: std.Mutex[Counter, ctx]
        }
        func increment_task(arg: *ThreadArg[ctx]) {
            mut i := 0;
            while i < 100 {
                unsafe {
                    mut val_ptr := (*arg).mutex.Lock();
                    (*val_ptr).count = (*val_ptr).count + 1;
                    (*arg).mutex.Unlock();
                }
                i = i + 1;
            }
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            
            mut m: std.Mutex[Counter, ctx] := std.MutexNew(ctx);
            unsafe {
                mut val := m.Lock();
                (*val).count = 0;
                m.Unlock();
            }

            mut arg: ThreadArg[ctx];
            arg.mutex = m;

            std.Spawn(increment_task, &arg);
            std.Spawn(increment_task, &arg);
            std.Spawn(increment_task, &arg);

            mut current_count := 0;
            while current_count < 300 {
                unsafe {
                    mut val := arg.mutex.Lock();
                    current_count = (*val).count;
                    arg.mutex.Unlock();
                }
                std.Yield();
            }

            os.LogInt(current_count);
        } 
    ";
    run_e2e_test(source, "300");
}

#[test]
fn test_e2e_channel_ping_pong() {
    let source = "
        type ChanArg[ctx] struct {
            in_chan: std.Channel[int, ctx],
            out_chan: std.Channel[int, ctx]
        }
        func worker_task(arg: *ChanArg[ctx]) {
            unsafe {
                mut val := (*arg).in_chan.Recv();
                (*arg).out_chan.Send(val + 100);
            }
        }
        func main() { 
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut in_c: std.Channel[int, ctx] := std.ChannelNew(ctx);
            mut out_c: std.Channel[int, ctx] := std.ChannelNew(ctx);

            mut arg: ChanArg[ctx];
            arg.in_chan = in_c;
            arg.out_chan = out_c;

            std.Spawn(worker_task, &arg);

            in_c.Send(42);
            mut result := out_c.Recv();

            os.LogInt(result);
        }
    ";
    run_e2e_test(source, "142");
}

#[test]
fn test_e2e_parallel_zero_copy_parsing() {
    let source = "
        type ASTNode struct {
            op: int,
            left_val: int,
            right_val: int
        }
        type ThreadArg[ctx] struct {
            file_ctx: Arena,
            out_chan: std.Channel[Arena, ctx]
        }
        func parser_thread(arg: *ThreadArg[ctx]) {
            unsafe {
                mut file_ctx := move (*arg).file_ctx;
                
                mut node: Index[ASTNode, file_ctx] := os.ArenaAlloc(file_ctx);
                file_ctx[node].op = 43;
                file_ctx[node].left_val = 200;
                file_ctx[node].right_val = 50;

                (*arg).out_chan.Send(move file_ctx);
            } 
        }
        func main() {
            mut main_ctx := os.Arena.New();
            defer main_ctx.Free();

            mut out_c: std.Channel[Arena, main_ctx] := std.ChannelNew(main_ctx);

            mut bg_ctx := os.Arena.New();

            mut arg: ThreadArg[main_ctx];
            arg.file_ctx = bg_ctx;
            arg.out_chan = out_c;

            std.Spawn(parser_thread, &arg);

            mut recv_ctx := out_c.Recv();
            defer recv_ctx.Free();

            mut node: Index[ASTNode, recv_ctx] := empty[Index[ASTNode, recv_ctx]];
            unsafe {
                node = 0 as Index[ASTNode, recv_ctx];
            }

            mut result := 0;
            if recv_ctx[node].op == 43 {
                result = recv_ctx[node].left_val + recv_ctx[node].right_val;
            }

            os.LogInt(result);
        } 
    ";
    run_e2e_test(source, "250");
}

#[test]
fn test_e2e_high_density_fiber_stress() {
    let mut c_program = String::new();
    c_program.push_str(gust_lexer::codegen_runtime::CORE_HEADERS);
    c_program.push_str(gust_lexer::codegen_runtime::FIBER_RUNTIME);

    c_program.push_str(
        r#"
        #include <assert.h>

        volatile int completed_count = 0;
        pthread_mutex_t count_lock = PTHREAD_MUTEX_INITIALIZER;

        void fiber_task(void* arg) {
            pthread_mutex_lock(&count_lock);
            completed_count++;
            pthread_mutex_unlock(&count_lock);
        }

        int main() {
            #if !defined(__x86_64__) && !defined(__aarch64__)
            printf("GUST_HIGH_DENSITY_OK\n");
            return 0;
            #endif

            gust_scheduler_init(1);
            for (int i = 0; i < 100000; i++) {
                gust_scheduler_spawn(16384, fiber_task, NULL);
            }
            gust_scheduler_destroy();
            assert(completed_count == 100000);
            printf("GUST_HIGH_DENSITY_OK\n");
            return 0;
        }
    "#,
    );

    let temp_dir = env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let count = TEST_COUNTER.fetch_add(1, Ordering::SeqCst);

    let c_filename = format!(
        "gust_stress_test_{:?}_{}_{}.c",
        thread_id, process_id, count
    );
    let bin_filename = format!(
        "gust_stress_test_{:?}_{}_{}.bin",
        thread_id, process_id, count
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    fs::write(&c_path, &c_program).expect("Failed to write temporary C file");

    let cc_compiler = env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let mut cmd = Command::new(&cc_compiler);
    cmd.arg(&c_path);
    if env::var("GUST_NO_SANITIZERS").is_err() {
        cmd.arg("-fsanitize=address,undefined");
    }
    let compile_output = cmd
        .arg("-o")
        .arg(&bin_path)
        .output()
        .expect("Compile command failed");

    assert!(
        compile_output.status.success(),
        "GCC compilation failed: {}",
        String::from_utf8_lossy(&compile_output.stderr)
    );

    let run_output = Command::new(&bin_path).output().expect("Execution failed");

    let _ = fs::remove_file(&c_path);
    let _ = fs::remove_file(&bin_path);

    assert!(run_output.status.success());
    let stdout_str = String::from_utf8(run_output.stdout).unwrap();
    assert!(
        stdout_str.contains("GUST_HIGH_DENSITY_OK"),
        "Unexpected output: {}",
        stdout_str
    );
}

#[test]
fn test_e2e_cooperative_deadlock_and_starvation() {
    let mut c_program = String::new();
    c_program.push_str(gust_lexer::codegen_runtime::CORE_HEADERS);
    c_program.push_str(gust_lexer::codegen_runtime::FIBER_RUNTIME);

    c_program.push_str(
        r#"
        #include <assert.h>

        volatile int heavy_completed = 0;
        volatile int light_completed = 0;

        void heavy_task(void* arg) {
            for (int i = 0; i < 1000; i++) {
                gust_yield();
            }
            heavy_completed = 1;
        }

        void light_task(void* arg) {
            assert(heavy_completed == 0);
            light_completed = 1;
        }

        int main() {
            #if !defined(__x86_64__) && !defined(__aarch64__)
            printf("GUST_STARVATION_OK\n");
            return 0;
            #endif

            gust_scheduler_init(1);
            gust_scheduler_spawn(16384, heavy_task, NULL);
            gust_scheduler_spawn(16384, light_task, NULL);
            gust_scheduler_destroy();
            assert(heavy_completed == 1);
            assert(light_completed == 1);
            printf("GUST_STARVATION_OK\n");
            return 0;
        }
    "#,
    );

    let temp_dir = env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let count = TEST_COUNTER.fetch_add(1, Ordering::SeqCst);

    let c_filename = format!(
        "gust_starvation_test_{:?}_{}_{}.c",
        thread_id, process_id, count
    );
    let bin_filename = format!(
        "gust_starvation_test_{:?}_{}_{}.bin",
        thread_id, process_id, count
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    fs::write(&c_path, &c_program).expect("Failed to write temporary C file");

    let cc_compiler = env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let mut cmd = Command::new(&cc_compiler);
    cmd.arg(&c_path);
    if env::var("GUST_NO_SANITIZERS").is_err() {
        cmd.arg("-fsanitize=address,undefined");
    }
    let compile_output = cmd
        .arg("-o")
        .arg(&bin_path)
        .output()
        .expect("Compile command failed");

    assert!(
        compile_output.status.success(),
        "GCC compilation failed: {}",
        String::from_utf8_lossy(&compile_output.stderr)
    );

    let run_output = Command::new(&bin_path).output().expect("Execution failed");

    let _ = fs::remove_file(&c_path);
    let _ = fs::remove_file(&bin_path);

    assert!(run_output.status.success());
    let stdout_str = String::from_utf8(run_output.stdout).unwrap();
    assert!(
        stdout_str.contains("GUST_STARVATION_OK"),
        "Unexpected output: {}",
        stdout_str
    );
}

#[test]
fn test_e2e_fiber_channel_pipeline() {
    let source = "
        type Packet struct {
            val: int
        }
        type StageArg[ctx] struct {
            in_chan: std.Channel[Arena, ctx],
            out_chan: std.Channel[Arena, ctx]
        }
        func stage_task(arg: *StageArg[ctx]) {
            unsafe {
                mut file_ctx := move (*arg).in_chan.Recv();
                mut node: Index[Packet, file_ctx] := 0 as Index[Packet, file_ctx];
                file_ctx[node].val = file_ctx[node].val + 100;
                (*arg).out_chan.Send(move file_ctx);
            }
        }
        func main() {
            mut main_ctx := os.Arena.New();
            defer main_ctx.Free();

            mut chan1: std.Channel[Arena, main_ctx] := std.ChannelNew(main_ctx);
            mut chan2: std.Channel[Arena, main_ctx] := std.ChannelNew(main_ctx);
            mut chan3: std.Channel[Arena, main_ctx] := std.ChannelNew(main_ctx);

            mut bg_ctx := os.Arena.New();
            mut node: Index[Packet, bg_ctx] := os.ArenaAlloc(bg_ctx);
            bg_ctx[node].val = 42;

            mut arg1: StageArg[main_ctx];
            arg1.in_chan = chan1;
            arg1.out_chan = chan2;

            mut arg2: StageArg[main_ctx];
            arg2.in_chan = chan2;
            arg2.out_chan = chan3;

            std.Spawn(stage_task, &arg1);
            std.Spawn(stage_task, &arg2);

            chan1.Send(move bg_ctx);

            mut final_ctx := chan3.Recv();
            defer final_ctx.Free();

            mut final_node: Index[Packet, final_ctx] := empty[Index[Packet, final_ctx]];
            unsafe {
                final_node = 0 as Index[Packet, final_ctx];
            }
            os.LogInt(final_ctx[final_node].val);
        }
    ";
    run_e2e_test(source, "242");
}

#[test]
fn test_e2e_process_args_and_exit() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut args: std.Vector[str, ctx] := os.Args(ctx);
            os.LogInt(len(args));
            os.LogStr(args[1]);
            os.LogStr(args[2]);
            os.Exit(42);
        }
    ";

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
        checker.resolved_names,
        checker.resolved_types,
    );
    let modules_for_codegen = vec![(std::path::PathBuf::from("input.gst"), program)];
    let c_code = codegen.generate(&modules_for_codegen);

    // 2. Write the transpiled C code to a temporary file
    let temp_dir = env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let count = TEST_COUNTER.fetch_add(1, Ordering::SeqCst);

    let c_filename = format!("gust_test_args_{:?}_{}_{}.c", thread_id, process_id, count);
    let bin_filename = format!(
        "gust_test_args_{:?}_{}_{}.bin",
        thread_id, process_id, count
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    fs::write(&c_path, &c_code).expect("Failed to write temporary C file");

    // 3. Invoke a system C compiler to compile it
    let cc_compiler = env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let mut cmd = Command::new(&cc_compiler);
    cmd.arg(&c_path);
    if env::var("GUST_NO_SANITIZERS").is_err() {
        cmd.arg("-fsanitize=address,undefined");
    }
    let compile_output = cmd.arg("-o").arg(&bin_path).output();

    let compile_success = match compile_output {
        Ok(output) => {
            if !output.status.success() {
                println!("--- GCC Compilation Failed ---");
                println!("STDOUT:\n{}", String::from_utf8_lossy(&output.stdout));
                println!("STDERR:\n{}", String::from_utf8_lossy(&output.stderr));
            }
            output.status.success()
        }
        Err(e) => {
            let _ = fs::remove_file(&c_path);
            panic!("CC failed: {:?}", e);
        }
    };
    assert!(compile_success, "C compilation failed");

    // 4. Run the compiled binary with custom arguments
    let run_output = Command::new(&bin_path)
        .arg("compile")
        .arg("file.gst")
        .output()
        .expect("Failed to execute binary");

    // Clean up temporary files immediately
    let _ = fs::remove_file(&c_path);
    let _ = fs::remove_file(&bin_path);

    // 5. Assert the exit code is 42
    assert_eq!(run_output.status.code(), Some(42));

    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");
    assert_eq!(stdout_str.trim(), "3\ncompile\nfile.gst");
}

#[test]
fn test_e2e_hashmap_extended_utilities() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
            map.Insert(10, 100);
            map.Insert(20, 200);
            map.Insert(30, 300);

            mut keys: std.Vector[int, ctx] := map.Keys(ctx);
            os.LogInt(len(keys));

            mut sum := 0;
            mut i := 0;
            while i < len(keys) {
                mut key := keys[i];
                mut lookup := map.Get(key);
                if lookup.Ok {
                    sum = sum + lookup.Val;
                }
                i = i + 1;
            }
            os.LogInt(sum);

            map.Remove(20);
            os.LogInt(len(map));

            mut lookup_removed := map.Get(20);
            if lookup_removed.Ok {
                os.LogInt(1);
            }
            else {
                os.LogInt(0);
            }

            map.Clear();
            os.LogInt(len(map));
        }
    ";
    run_e2e_test(source, "3\n600\n2\n0\n0");
}

#[test]
fn test_e2e_character_classification_and_parsing() {
    let source = "
        func main() {
            mut s := \"   -42069   \";
            mut start := 0;
            mut end := len(s);
            
            while start < len(s) {
                mut b := std.str_byte_at(s, start);
                if std.is_whitespace(b) {
                    start = start + 1;
                } else {
                    end = start;
                    start = len(s);
                }
            }
            mut num_start := end;
            
            mut num_end := num_start;
            mut loop_active := 1;
            while loop_active == 1 {
                if num_end < len(s) {
                    mut b := std.str_byte_at(s, num_end);
                    if std.is_whitespace(b) {
                        loop_active = 0;
                    } else {
                        num_end = num_end + 1;
                    }
                } else {
                    loop_active = 0;
                }
            }
            
            mut num_slice := std.str_slice(s, num_start, num_end);
            
            mut idx := 0;
            mut is_valid := 1;
            while idx < len(num_slice) {
                mut b := std.str_byte_at(num_slice, idx);
                if idx == 0 {
                    if b == 45 {
                        // negative sign '-'
                    } else {
                        if std.is_digit(b) {
                            // digit
                        } else {
                            is_valid = 0;
                        }
                    }
                } else {
                    if std.is_digit(b) {
                        // digit
                    } else {
                        is_valid = 0;
                    }
                }
                idx = idx + 1;
            }
            
            if is_valid == 1 {
                mut val := std.parse_int(num_slice);
                mut result := val * 2;
                os.LogInt(result);
            } else {
                os.LogInt(0);
            }
        }
    ";
    run_e2e_test(source, "-84138");
}

#[test]
fn test_e2e_vector_stack_lifo_parser() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            
            mut stack: std.Vector[int, ctx] := std.VectorNew(ctx);
            stack.Push(10);
            stack.Push(20);
            stack.Push(30);
            
            // Inspect the tail with Back
            unsafe {
                mut top := stack.Back();
                os.LogInt(*top);
                
                // Mutate in-place
                *top = 35;
            }
            
            // Pop off in LIFO order
            os.LogInt(stack.Pop());
            os.LogInt(stack.Pop());
            
            // Push another
            stack.Push(40);
            os.LogInt(len(stack));
            
            // Clear the stack
            stack.Clear();
            os.LogInt(len(stack));
        }
    ";
    run_e2e_test(source, "30\n35\n20\n2\n0");
}

#[test]
fn test_e2e_guard_hashmap_lookup() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut map: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
            map.Insert(42, 100);

            guard val := map.Get(42) else {
                os.LogInt(0);
                return;
            }

            os.LogInt(val);
        }
    ";
    run_e2e_test(source, "100");
}

#[test]
fn test_e2e_guard_mutability() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut map: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
            map.Insert(10, 50);

            guard mut val := map.Get(10) else {
                return;
            }

            val = val + 50;
            os.LogInt(val);
        }
    ";
    run_e2e_test(source, "100");
}

#[test]
fn test_e2e_guard_cast() {
    let source = "
        type Packet struct {
            ProtocolID: int,
            Length: int
        }

        func main() {
            mut payload := os.MockPayload();
            
            guard p := payload as &Packet else {
                os.LogInt(0);
                return;
            }

            os.LogInt(p.ProtocolID);
        }
    ";
    run_e2e_test(source, "42");
}

#[test]
fn test_e2e_str_find_and_trim() {
    let source = r#"
        func main() {
            mut s := "  hello  ";
            mut trimmed := std.str_trim(s);
            os.LogStr(trimmed);

            mut idx1 := std.str_find(trimmed, "ll");
            os.LogInt(idx1);

            mut idx2 := std.str_find(trimmed, "xx");
            os.LogInt(idx2);
        }
    "#;
    run_e2e_test(source, "hello\n2\n-1");
}

#[test]
fn test_e2e_str_split() {
    let source = r#"
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut s := "a,b,c,d";
            mut parts := std.str_split(s, ",", ctx);
            os.LogInt(len(parts));
            os.LogStr(parts[0]);
            os.LogStr(parts[1]);
            os.LogStr(parts[2]);
            os.LogStr(parts[3]);

            mut s2 := "xyz";
            mut parts2 := std.str_split(s2, "", ctx);
            os.LogInt(len(parts2));
            os.LogStr(parts2[0]);
            os.LogStr(parts2[1]);
            os.LogStr(parts2[2]);

            mut parts3 := std.str_split(s, "x", ctx);
            os.LogInt(len(parts3));
            os.LogStr(parts3[0]);
        }
    "#;
    run_e2e_test(source, "4\na\nb\nc\nd\n3\nx\ny\nz\n1\na,b,c,d");
}

#[test]
fn test_e2e_path_join() {
    let source = r#"
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut p1 := os.path_join("a/b", "c", ctx);
            os.LogStr(p1);

            mut p2 := os.path_join("a/b", "../c", ctx);
            os.LogStr(p2);

            mut p3 := os.path_join("a/./b", "c/../d", ctx);
            os.LogStr(p3);

            mut p4 := os.path_join("/a/b/", "/c", ctx);
            os.LogStr(p4);

            mut p5 := os.path_join("a/b", "../../c", ctx);
            os.LogStr(p5);
        }
    "#;
    run_e2e_test(source, "a/b/c\na/c\na/b/d\n/a/b/c\n../c");
}

#[test]
fn test_e2e_thread_local_dynamic_swapping() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            os.SetThreadScratch(ctx);
            
            os.LogInt(ctx.Offset);
            mut s := std.FormatInt(123);
            os.LogInt(ctx.Offset);
        }
    ";
    run_e2e_test(source, "0\n16");
}

#[test]
fn test_e2e_multithreaded_scratch_isolation() {
    let source = "
        type ThreadArg[ctx] struct {
            val: int,
            done: std.Channel[int, ctx]
        }
        func thread_task(arg: *ThreadArg[ctx]) {
            mut t_ctx := os.Arena.New();
            defer t_ctx.Free();
            os.SetThreadScratch(t_ctx);
            
            mut val := 0;
            unsafe {
                val = (*arg).val;
            }
            mut s := std.FormatInt(val);
            
            mut i := 0;
            while i < 20000 {
                i = i + 1;
            }
            
            mut s_parsed := std.parse_int(s);
            
            unsafe {
                (*arg).done.Send(s_parsed);
            }
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            
            mut c1: std.Channel[int, ctx] := std.ChannelNew(ctx);
            mut c2: std.Channel[int, ctx] := std.ChannelNew(ctx);
            
            mut arg1: ThreadArg[ctx];
            arg1.val = 42;
            arg1.done = c1;
            
            mut arg2: ThreadArg[ctx];
            arg2.val = 100;
            arg2.done = c2;
            
            std.Spawn(thread_task, &arg1);
            std.Spawn(thread_task, &arg2);
            
            mut res1 := c1.Recv();
            mut res2 := c2.Recv();
            
            os.LogInt(res1);
            os.LogInt(res2);
        }
    ";
    run_e2e_test(source, "42\n100");
}

#[test]
fn test_e2e_arena_canary_normal_debug() {
    let source = "
        type MyNode[ctx] struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut n1: Index[MyNode, ctx] := os.ArenaAlloc(ctx);
            mut n2: Index[MyNode, ctx] := os.ArenaAlloc(ctx);
            ctx[n1].val = 42;
            ctx[n2].val = 84;
            
            os.ArenaValidate(ctx);
            os.LogInt(ctx[n1].val);
            os.LogInt(ctx[n2].val);
        }
    ";

    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    assert!(
        parser.errors.is_empty(),
        "Parser errors: {:?}",
        parser.errors
    );

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
        checker.resolved_names,
        checker.resolved_types,
    );
    let modules_for_codegen = vec![(std::path::PathBuf::from("input.gst"), program)];
    let c_code = codegen.generate(&modules_for_codegen);

    let temp_dir = env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let count = TEST_COUNTER.fetch_add(1, Ordering::SeqCst);

    let c_filename = format!(
        "gust_canary_normal_{:?}_{}_{}.c",
        thread_id, process_id, count
    );
    let bin_filename = format!(
        "gust_canary_normal_{:?}_{}_{}.bin",
        thread_id, process_id, count
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    fs::write(&c_path, &c_code).expect("Failed to write temporary C file");

    let cc_compiler = env::var("CC").unwrap_or_else(|_| "cc".to_string());

    let compile_res = Command::new(&cc_compiler)
        .arg(&c_path)
        .arg("-DGUST_DEBUG")
        .arg("-o")
        .arg(&bin_path)
        .output()
        .expect("Compile failed");
    assert!(
        compile_res.status.success(),
        "Compile failed: {}",
        String::from_utf8_lossy(&compile_res.stderr)
    );

    let run_res = Command::new(&bin_path).output().expect("Execution failed");

    let _ = fs::remove_file(&c_path);
    let _ = fs::remove_file(&bin_path);

    assert!(run_res.status.success());
    let stdout_str = String::from_utf8(run_res.stdout).unwrap();
    assert_eq!(stdout_str.trim(), "42\n84");
}

#[test]
fn test_e2e_arena_canary_corruption_detection() {
    let source = "
        type MyNode[ctx] struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut n1: Index[MyNode, ctx] := os.ArenaAlloc(ctx);
            ctx[n1].val = 42;
            
            unsafe {
                mut val_ptr := &ctx[n1].val;
                mut byte_ptr := val_ptr as *byte;
                *(byte_ptr + 8) = 0; // Corrupt post-canary of n1
            }
            
            os.ArenaValidate(ctx);
        }
    ";

    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    assert!(
        parser.errors.is_empty(),
        "Parser errors: {:?}",
        parser.errors
    );

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
        checker.resolved_names,
        checker.resolved_types,
    );
    let modules_for_codegen = vec![(std::path::PathBuf::from("input.gst"), program)];
    let c_code = codegen.generate(&modules_for_codegen);

    let temp_dir = env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let count = TEST_COUNTER.fetch_add(1, Ordering::SeqCst);

    let c_filename = format!(
        "gust_canary_corrupt_{:?}_{}_{}.c",
        thread_id, process_id, count
    );
    let bin_filename = format!(
        "gust_canary_corrupt_{:?}_{}_{}.bin",
        thread_id, process_id, count
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    fs::write(&c_path, &c_code).expect("Failed to write temporary C file");

    let cc_compiler = env::var("CC").unwrap_or_else(|_| "cc".to_string());

    let compile_res = Command::new(&cc_compiler)
        .arg(&c_path)
        .arg("-DGUST_DEBUG")
        .arg("-o")
        .arg(&bin_path)
        .output()
        .expect("Compile failed");
    assert!(
        compile_res.status.success(),
        "Compile failed: {}",
        String::from_utf8_lossy(&compile_res.stderr)
    );

    let run_res = Command::new(&bin_path).output().expect("Execution failed");

    let _ = fs::remove_file(&c_path);
    let _ = fs::remove_file(&bin_path);

    // It must crash because of abort()
    assert!(!run_res.status.success());
    let stderr_str = String::from_utf8_lossy(&run_res.stderr);
    let stdout_str = String::from_utf8_lossy(&run_res.stdout);

    let combined = format!("{}\n{}", stdout_str, stderr_str);
    assert!(
        combined.contains("Assertion Failure") || combined.contains("corruption detected"),
        "Unexpected output: {}",
        combined
    );
}

#[test]
fn test_e2e_fiber_low_level_context_switch() {
    let mut c_program = String::new();
    c_program.push_str(gust_lexer::codegen_runtime::CORE_HEADERS);
    c_program.push_str(gust_lexer::codegen_runtime::FIBER_RUNTIME);

    c_program.push_str(r#"
        gust_Fiber* main_fiber = NULL;
        gust_Fiber* fiber1 = NULL;
        gust_Fiber* fiber2 = NULL;

        int fiber1_run_count = 0;
        int fiber2_run_count = 0;
        uintptr_t fiber1_sp_val = 0;
        uintptr_t fiber2_sp_val = 0;
        pthread_t main_thread_id;
        int thread_mismatch_detected = 0;

        void fiber1_entry(void* arg) {
            int local_var = 42;
            fiber1_sp_val = (uintptr_t)&local_var;
            fiber1_run_count++;

            pthread_t curr_thread = pthread_self();
            if (!pthread_equal(main_thread_id, curr_thread)) {
                thread_mismatch_detected = 1;
            }

            // Switch to fiber2
            gust_fiber_switch(fiber1, fiber2);

            // Resume after fiber2 switches back
            fiber1_run_count++;
            gust_fiber_switch(fiber1, main_fiber);
        }

        void fiber2_entry(void* arg) {
            int local_var = 84;
            fiber2_sp_val = (uintptr_t)&local_var;
            fiber2_run_count++;

            pthread_t curr_thread = pthread_self();
            if (!pthread_equal(main_thread_id, curr_thread)) {
                thread_mismatch_detected = 1;
            }

            // Switch back to fiber1
            gust_fiber_switch(fiber2, fiber1);
        }

        int main() {
            #if !defined(__x86_64__) && !defined(__aarch64__)
            // Skip actual execution if CPU is unsupported
            printf("GUST_FIBER_TEST_OK\n");
            return 0;
            #endif

            main_thread_id = pthread_self();

            main_fiber = (gust_Fiber*)malloc(sizeof(gust_Fiber));
            main_fiber->state = GUST_FIBER_RUNNING;
            main_fiber->stack_base = NULL;
            main_fiber->stack_size = 0;
            main_fiber->sp = NULL;
            main_fiber->parent = NULL;

            fiber1 = gust_fiber_create(16384, fiber1_entry, NULL);
            fiber2 = gust_fiber_create(16384, fiber2_entry, NULL);

            fiber1->parent = main_fiber;
            fiber2->parent = fiber1;

            // Switch to fiber1
            gust_fiber_switch(main_fiber, fiber1);

            // Verification assertions
            if (fiber1_run_count != 2) {
                printf("Error: fiber1_run_count is %d, expected 2\n", fiber1_run_count);
                return 1;
            }
            if (fiber2_run_count != 1) {
                printf("Error: fiber2_run_count is %d, expected 1\n", fiber2_run_count);
                return 1;
            }
            if (thread_mismatch_detected) {
                printf("Error: Thread mismatch detected across fiber execution\n");
                return 1;
            }

            // Verify separate stacks
            uintptr_t stack_diff = (fiber1_sp_val > fiber2_sp_val) ? 
                (fiber1_sp_val - fiber2_sp_val) : (fiber2_sp_val - fiber1_sp_val);
            if (stack_diff < 4096) {
                printf("Error: Stacks are not sufficiently separated (diff: %zu bytes)\n", (size_t)stack_diff);
                return 1;
            }

            gust_fiber_free(fiber1);
            gust_fiber_free(fiber2);
            free(main_fiber);

            printf("GUST_FIBER_TEST_OK\n");
            return 0;
        }
    "#);

    let temp_dir = env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let count = TEST_COUNTER.fetch_add(1, Ordering::SeqCst);

    let c_filename = format!(
        "gust_fiber_switch_test_{:?}_{}_{}.c",
        thread_id, process_id, count
    );
    let bin_filename = format!(
        "gust_fiber_switch_test_{:?}_{}_{}.bin",
        thread_id, process_id, count
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    fs::write(&c_path, &c_program).expect("Failed to write temporary C file");

    let cc_compiler = env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let compile_output = Command::new(&cc_compiler)
        .arg(&c_path)
        .arg("-o")
        .arg(&bin_path)
        .output()
        .expect("Compile command failed");

    assert!(
        compile_output.status.success(),
        "GCC compilation failed: {}",
        String::from_utf8_lossy(&compile_output.stderr)
    );

    let run_output = Command::new(&bin_path).output().expect("Execution failed");

    let _ = fs::remove_file(&c_path);
    let _ = fs::remove_file(&bin_path);

    assert!(run_output.status.success());
    let stdout_str = String::from_utf8(run_output.stdout).unwrap();
    assert!(
        stdout_str.contains("GUST_FIBER_TEST_OK"),
        "Unexpected output: {}",
        stdout_str
    );
}

#[test]
fn test_e2e_fiber_register_preservation() {
    let mut c_program = String::new();
    c_program.push_str(gust_lexer::codegen_runtime::CORE_HEADERS);
    c_program.push_str(gust_lexer::codegen_runtime::FIBER_RUNTIME);

    c_program.push_str(r#"
        gust_Fiber* main_fiber = NULL;
        gust_Fiber* fiber1 = NULL;
        pthread_t main_thread_id;

        void fiber1_entry(void* arg) {
            // Modifying callee-saved registers within fiber1 should not affect main_fiber's values
            #if defined(__x86_64__)
            __asm__ volatile (
                "movq $0xDEADBEEF, %rbx\n\t"
                "movq $0xCAFEbabe, %r12\n\t"
            );
            #elif defined(__aarch64__)
            __asm__ volatile (
                "mov x19, #0xDEAD\n\t"
                "mov x20, #0xCAFE\n\t"
            );
            #endif

            // Switch back to main_fiber
            gust_fiber_switch(fiber1, main_fiber);
        }

        int main() {
            #if !defined(__x86_64__) && !defined(__aarch64__)
            // Skip actual execution if CPU is unsupported
            printf("GUST_FIBER_REG_OK\n");
            return 0;
            #endif

            main_thread_id = pthread_self();

            main_fiber = (gust_Fiber*)malloc(sizeof(gust_Fiber));
            main_fiber->state = GUST_FIBER_RUNNING;
            main_fiber->stack_base = NULL;
            main_fiber->stack_size = 0;
            main_fiber->sp = NULL;
            main_fiber->parent = NULL;
            main_fiber->next = NULL;

            fiber1 = gust_fiber_create(16384, fiber1_entry, NULL);
            fiber1->parent = main_fiber;

            // Load distinct canary values into callee-saved registers in main thread
            volatile uint64_t canary1 = 0x1111222233334444ULL;
            volatile uint64_t canary2 = 0x5555666677778888ULL;

            #if defined(__x86_64__)
            __asm__ volatile (
                "movq %0, %%rbx\n\t"
                "movq %1, %%r12\n\t"
                :
                : "r"(canary1), "r"(canary2)
                : "rbx", "r12"
            );
            #elif defined(__aarch64__)
            __asm__ volatile (
                "mov x19, %0\n\t"
                "mov x20, %1\n\t"
                :
                : "r"(canary1), "r"(canary2)
                : "x19", "x20"
            );
            #endif

            // Switch to fiber1, which will alter its own callee registers and return
            gust_fiber_switch(main_fiber, fiber1);

            // Read the callee-saved registers back
            uint64_t out1 = 0, out2 = 0;
            #if defined(__x86_64__)
            __asm__ volatile (
                "movq %%rbx, %0\n\t"
                "movq %%r12, %1\n\t"
                : "=r"(out1), "=r"(out2)
            );
            #elif defined(__aarch64__)
            __asm__ volatile (
                "mov %0, x19\n\t"
                "mov %1, x20\n\t"
                : "=r"(out1), "=r"(out2)
            );
            #endif

            if (out1 != canary1 || out2 != canary2) {
                printf("Error: Register corruption detected! Expected %llx and %llx, got %llx and %llx\n",
                       (unsigned long long)canary1, (unsigned long long)canary2,
                       (unsigned long long)out1, (unsigned long long)out2);
                return 1;
            }

            gust_fiber_free(fiber1);
            free(main_fiber);

            printf("GUST_FIBER_REG_OK\n");
            return 0;
        }
    "#);

    let temp_dir = env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let count = TEST_COUNTER.fetch_add(1, Ordering::SeqCst);

    let c_filename = format!(
        "gust_fiber_reg_test_{:?}_{}_{}.c",
        thread_id, process_id, count
    );
    let bin_filename = format!(
        "gust_fiber_reg_test_{:?}_{}_{}.bin",
        thread_id, process_id, count
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    fs::write(&c_path, &c_program).expect("Failed to write temporary C file");

    let cc_compiler = env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let compile_output = Command::new(&cc_compiler)
        .arg(&c_path)
        .arg("-o")
        .arg(&bin_path)
        .output()
        .expect("Compile command failed");

    assert!(
        compile_output.status.success(),
        "GCC compilation failed: {}",
        String::from_utf8_lossy(&compile_output.stderr)
    );

    let run_output = Command::new(&bin_path).output().expect("Execution failed");

    let _ = fs::remove_file(&c_path);
    let _ = fs::remove_file(&bin_path);

    assert!(run_output.status.success());
    let stdout_str = String::from_utf8(run_output.stdout).unwrap();
    assert!(
        stdout_str.contains("GUST_FIBER_REG_OK"),
        "Unexpected output: {}",
        stdout_str
    );
}

#[test]
fn test_e2e_scheduler_affinity_binding() {
    let mut c_program = String::new();
    c_program.push_str(gust_lexer::codegen_runtime::CORE_HEADERS);
    c_program.push_str(gust_lexer::codegen_runtime::FIBER_RUNTIME);

    c_program.push_str(
        r#"
        #include <assert.h>

        void dummy_task(void* arg) {
            // No-op
        }

        int main() {
            gust_scheduler_init(2);
            
            usleep(20000);

            #if defined(__linux__)
            cpu_set_t cpuset;
            for (int i = 0; i < 2; i++) {
                CPU_ZERO(&cpuset);
                int rc = pthread_getaffinity_np(gust_shards[i].thread, sizeof(cpu_set_t), &cpuset);
                assert(rc == 0);
                assert(CPU_ISSET(i, &cpuset));
            }
            #endif

            gust_scheduler_spawn(16384, dummy_task, NULL);
            
            usleep(10000);

            gust_scheduler_destroy();
            printf("GUST_AFFINITY_OK\n");
            return 0;
        }
    "#,
    );

    let temp_dir = env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let count = TEST_COUNTER.fetch_add(1, Ordering::SeqCst);

    let c_filename = format!(
        "gust_affinity_test_{:?}_{}_{}.c",
        thread_id, process_id, count
    );
    let bin_filename = format!(
        "gust_affinity_test_{:?}_{}_{}.bin",
        thread_id, process_id, count
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    fs::write(&c_path, &c_program).expect("Failed to write temporary C file");

    let cc_compiler = env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let mut cmd = Command::new(&cc_compiler);
    cmd.arg(&c_path);
    if env::var("GUST_NO_SANITIZERS").is_err() {
        cmd.arg("-fsanitize=address,undefined");
    }
    let compile_output = cmd
        .arg("-o")
        .arg(&bin_path)
        .output()
        .expect("Compile command failed");

    assert!(
        compile_output.status.success(),
        "GCC compilation failed: {}",
        String::from_utf8_lossy(&compile_output.stderr)
    );

    let run_output = Command::new(&bin_path).output().expect("Execution failed");

    let _ = fs::remove_file(&c_path);
    let _ = fs::remove_file(&bin_path);

    assert!(run_output.status.success());
    let stdout_str = String::from_utf8(run_output.stdout).unwrap();
    assert!(
        stdout_str.contains("GUST_AFFINITY_OK"),
        "Unexpected output: {}",
        stdout_str
    );
}

#[test]
fn test_e2e_scheduler_yield() {
    let mut c_program = String::new();
    c_program.push_str(gust_lexer::codegen_runtime::CORE_HEADERS);
    c_program.push_str(gust_lexer::codegen_runtime::FIBER_RUNTIME);

    c_program.push_str(r#"
        #include <assert.h>

        int f1_step = 0;
        int f2_step = 0;
        int execution_order[4] = {0};
        int order_idx = 0;
        pthread_mutex_t order_lock = PTHREAD_MUTEX_INITIALIZER;

        void f1_entry(void* arg) {
            pthread_mutex_lock(&order_lock);
            execution_order[order_idx++] = 1;
            pthread_mutex_unlock(&order_lock);
            f1_step++;

            gust_yield();

            pthread_mutex_lock(&order_lock);
            execution_order[order_idx++] = 3;
            pthread_mutex_unlock(&order_lock);
            f1_step++;
        }

        void f2_entry(void* arg) {
            pthread_mutex_lock(&order_lock);
            execution_order[order_idx++] = 2;
            pthread_mutex_unlock(&order_lock);
            f2_step++;

            gust_yield();

            pthread_mutex_lock(&order_lock);
            execution_order[order_idx++] = 4;
            pthread_mutex_unlock(&order_lock);
            f2_step++;
        }

        int main() {
            gust_scheduler_init(1);

            gust_scheduler_spawn(16384, f1_entry, NULL);
            gust_scheduler_spawn(16384, f2_entry, NULL);

            usleep(20000);

            gust_scheduler_destroy();

            if (f1_step != 2 || f2_step != 2) {
                printf("Error: Expected steps (2, 2), got (%d, %d)\n", f1_step, f2_step);
                return 1;
            }

            if (execution_order[0] != 1 || execution_order[1] != 2 ||
                execution_order[2] != 3 || execution_order[3] != 4) {
                printf("Error: Out of order interleaving: %d, %d, %d, %d\n",
                       execution_order[0], execution_order[1], execution_order[2], execution_order[3]);
                return 1;
            }

            printf("GUST_YIELD_OK\n");
            return 0;
        }
    "#);

    let temp_dir = env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let count = TEST_COUNTER.fetch_add(1, Ordering::SeqCst);

    let c_filename = format!("gust_yield_test_{:?}_{}_{}.c", thread_id, process_id, count);
    let bin_filename = format!(
        "gust_yield_test_{:?}_{}_{}.bin",
        thread_id, process_id, count
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    fs::write(&c_path, &c_program).expect("Failed to write temporary C file");

    let cc_compiler = env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let mut cmd = Command::new(&cc_compiler);
    cmd.arg(&c_path);
    if env::var("GUST_NO_SANITIZERS").is_err() {
        cmd.arg("-fsanitize=address,undefined");
    }
    let compile_output = cmd
        .arg("-o")
        .arg(&bin_path)
        .output()
        .expect("Compile command failed");

    assert!(
        compile_output.status.success(),
        "GCC compilation failed: {}",
        String::from_utf8_lossy(&compile_output.stderr)
    );

    let run_output = Command::new(&bin_path).output().expect("Execution failed");

    let _ = fs::remove_file(&c_path);
    let _ = fs::remove_file(&bin_path);

    assert!(run_output.status.success());
    let stdout_str = String::from_utf8(run_output.stdout).unwrap();
    assert!(
        stdout_str.contains("GUST_YIELD_OK"),
        "Unexpected output: {}",
        stdout_str
    );
}

#[test]
fn test_e2e_generational_arena_wrapper_migration() {
    let source = "
        type Node struct {
            val: int,
            next: Index[Node, ctx]
        }

        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut arena: std.GenerationalArena[Node, ctx];
            arena.current_ctx = os.Arena.New();
            defer arena.current_ctx.Free();
            arena.next_ctx = os.Arena.New();
            defer arena.next_ctx.Free();

            arena.survivor = os.ArenaAlloc(arena.current_ctx);
            arena.current_ctx[arena.survivor].val = 0;
            arena.current_ctx[arena.survivor].next = null;

            mut i := 0;
            while i < 1000 {
                mut temp: Index[Node, arena.current_ctx] := os.ArenaAlloc(arena.current_ctx);
                arena.current_ctx[temp].val = i;

                mut new_child: Index[Node, arena.current_ctx] := os.ArenaAlloc(arena.current_ctx);
                arena.current_ctx[new_child].val = i * 2;
                arena.current_ctx[new_child].next = null;

                arena.current_ctx[arena.survivor].next = new_child;
                arena.current_ctx[arena.survivor].val = arena.current_ctx[arena.survivor].val + arena.current_ctx[temp].val;

                arena.Step();

                i = i + 1;
            }

            os.LogInt(arena.current_ctx[arena.survivor].val);
            mut child_idx := arena.current_ctx[arena.survivor].next;
            os.LogInt(arena.current_ctx[child_idx].val);
        }
    ";
    run_e2e_test(source, "499500\n1998");
}

#[test]
fn test_e2e_sanitizer_detection_of_corrupt_memory() {
    if env::var("GUST_NO_SANITIZERS").is_ok() {
        println!(
            "Skipping test_e2e_sanitizer_detection_of_corrupt_memory because GUST_NO_SANITIZERS is set"
        );
        return;
    }

    let source = "
        func main() {
            mut ctx := os.Arena.New();
            mut idx := os.ArenaAlloc(ctx);
            unsafe {
                mut ptr := &ctx[idx].SessionID;
                ctx.Free();
                os.LogInt(*ptr); // Heap use-after-free!
            }
        }
    ";

    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    assert!(
        parser.errors.is_empty(),
        "Parser errors: {:?}",
        parser.errors
    );

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
        checker.resolved_names,
        checker.resolved_types,
    );
    let modules_for_codegen = vec![(std::path::PathBuf::from("input.gst"), program)];
    let c_code = codegen.generate(&modules_for_codegen);

    let temp_dir = env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let count = TEST_COUNTER.fetch_add(1, Ordering::SeqCst);

    let c_filename = format!(
        "gust_sanitizer_corrupt_{:?}_{}_{}.c",
        thread_id, process_id, count
    );
    let bin_filename = format!(
        "gust_sanitizer_corrupt_{:?}_{}_{}.bin",
        thread_id, process_id, count
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    fs::write(&c_path, &c_code).expect("Failed to write temporary C file");

    let cc_compiler = env::var("CC").unwrap_or_else(|_| "cc".to_string());

    let compile_res = Command::new(&cc_compiler)
        .arg(&c_path)
        .arg("-fsanitize=address,undefined")
        .arg("-o")
        .arg(&bin_path)
        .output()
        .expect("Compile failed");

    if !compile_res.status.success() {
        let _ = fs::remove_file(&c_path);
        println!(
            "Skipping test because compiler does not support sanitizers: {}",
            String::from_utf8_lossy(&compile_res.stderr)
        );
        return;
    }

    let run_res = Command::new(&bin_path).output().expect("Execution failed");

    let _ = fs::remove_file(&c_path);
    let _ = fs::remove_file(&bin_path);

    assert!(
        !run_res.status.success(),
        "Expected sanitizer violation to cause crash, but binary exited successfully!"
    );

    let stderr_str = String::from_utf8_lossy(&run_res.stderr);
    let stdout_str = String::from_utf8_lossy(&run_res.stdout);
    let combined = format!("{}\n{}", stdout_str, stderr_str);

    assert!(
        combined.contains("AddressSanitizer")
            || combined.contains("stack-buffer-overflow")
            || combined.contains("UndefinedBehaviorSanitizer"),
        "Expected sanitizer error message, but got:\n{}",
        combined
    );
}

#[test]
fn test_e2e_line_preprocessor_validation() {
    // This program transpiles to C containing #line directives and is compiled under ASan and UBSan
    let source = "
        func main() {
            mut x := 10;
            os.LogInt(x);
        }
    ";
    run_e2e_test(source, "10");
}

#[test]
fn test_e2e_self_hosted_lexer() {
    gust_lexer::init_logging();
    let temp_dir = std::env::temp_dir().join("gust_e2e_self_hosted_lexer");
    std::fs::create_dir_all(&temp_dir).unwrap();

    let token_src =
        std::fs::read_to_string("compiler/token.gst").expect("compiler/token.gst missing");
    let lexer_src =
        std::fs::read_to_string("compiler/lexer.gst").expect("compiler/lexer.gst missing");

    let token_path = temp_dir.join("token.gst");
    let lexer_path = temp_dir.join("lexer.gst");
    let entry_path = temp_dir.join("lexer_e2e_entry.gst");

    std::fs::write(&token_path, &token_src).unwrap();
    std::fs::write(&lexer_path, &lexer_src).unwrap();

    let input_source = "func add(x: int, y: int) int {\n    return x + y;\n}";

    let entry_source = format!(
        "
        import \"token.gst\" as token;
        import \"lexer.gst\" as lexer;
        func main() {{
            mut ctx := os.Arena.New();
            defer ctx.Free();
            
            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, {:?});
            
            mut loop_active := 1;
            while loop_active == 1 {{
                mut t: token.Token[ctx];
                lexer.next_token(&l, &t);
                os.LogInt(t.token_type.tag);
                os.LogStr(t.literal);
                if t.token_type.tag == 0 {{
                    loop_active = 0;
                }}
            }}
        }}
        ",
        input_source
    );

    std::fs::write(&entry_path, &entry_source).unwrap();

    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, mut modules) = res.unwrap();

    let mut checker = gust_lexer::typechecker::TypeChecker::new();
    for path in &order {
        if let Some(module) = modules.get(path) {
            let stem = path.file_stem().unwrap().to_str().unwrap();
            let is_entry = path == order.last().unwrap();
            let prefix = if is_entry {
                "".to_string()
            } else {
                format!("{}__", stem)
            };
            let check_res = checker.check_module(&module.program, &prefix);
            assert!(
                check_res.is_ok(),
                "Typechecking failed on {:?}: {:?}",
                path,
                check_res.err()
            );
        }
    }

    let mut modules_for_codegen = Vec::new();
    for path in &order {
        if let Some(module) = modules.get_mut(path) {
            modules_for_codegen.push((path.clone(), module.program.clone()));
        }
    }

    let codegen = gust_lexer::codegen::Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
        checker.enum_registry,
        checker.resolved_names,
        checker.resolved_types,
    );
    let c_code = codegen.generate(&modules_for_codegen);

    let count = 9999;
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let c_filename = format!("gust_e2e_lexer_{:?}_{}_{}.c", thread_id, process_id, count);
    let bin_filename = format!(
        "gust_e2e_lexer_{:?}_{}_{}.bin",
        thread_id, process_id, count
    );

    let c_path = std::env::temp_dir().join(&c_filename);
    let bin_path = std::env::temp_dir().join(&bin_filename);

    std::fs::write(&c_path, &c_code).expect("Failed to write temporary C file");

    let cc_compiler = std::env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let mut cmd = std::process::Command::new(&cc_compiler);
    cmd.arg(&c_path);
    if std::env::var("GUST_NO_SANITIZERS").is_err() {
        cmd.arg("-fsanitize=address,undefined");
    }
    let compile_output = cmd
        .arg("-o")
        .arg(&bin_path)
        .output()
        .expect("GCC command failed");

    assert!(
        compile_output.status.success(),
        "Compilation failed: {}",
        String::from_utf8_lossy(&compile_output.stderr)
    );

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_file(entry_path);
    let _ = std::fs::remove_file(token_path);
    let _ = std::fs::remove_file(lexer_path);
    let _ = std::fs::remove_dir(temp_dir);

    assert!(run_output.status.success());
    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    let expected_output = get_expected_lexer_output(input_source);

    assert_eq!(stdout_str.trim(), expected_output.trim());
}

fn get_expected_lexer_output(source: &str) -> String {
    let mut lexer = gust_lexer::lexer::Lexer::new(source);
    let mut out = String::new();
    loop {
        let tok = lexer.next_token();
        let tag = match tok.token_type {
            gust_lexer::token::TokenType::Eof => 0,
            gust_lexer::token::TokenType::Illegal => 1,
            gust_lexer::token::TokenType::Ident => 2,
            gust_lexer::token::TokenType::Int => 3,
            gust_lexer::token::TokenType::String => 4,
            gust_lexer::token::TokenType::Assign => 5,
            gust_lexer::token::TokenType::Eq => 6,
            gust_lexer::token::TokenType::Dot => 7,
            gust_lexer::token::TokenType::Comma => 8,
            gust_lexer::token::TokenType::Colon => 9,
            gust_lexer::token::TokenType::Semicolon => 10,
            gust_lexer::token::TokenType::LParen => 11,
            gust_lexer::token::TokenType::RParen => 12,
            gust_lexer::token::TokenType::LBrace => 13,
            gust_lexer::token::TokenType::RBrace => 14,
            gust_lexer::token::TokenType::LBracket => 15,
            gust_lexer::token::TokenType::RBracket => 16,
            gust_lexer::token::TokenType::Ampersand => 17,
            gust_lexer::token::TokenType::FatArrow => 18,
            gust_lexer::token::TokenType::Plus => 19,
            gust_lexer::token::TokenType::Minus => 20,
            gust_lexer::token::TokenType::Asterisk => 21,
            gust_lexer::token::TokenType::Slash => 22,
            gust_lexer::token::TokenType::EqEq => 23,
            gust_lexer::token::TokenType::NotEq => 24,
            gust_lexer::token::TokenType::Lt => 25,
            gust_lexer::token::TokenType::Gt => 26,
            gust_lexer::token::TokenType::LtEq => 48,
            gust_lexer::token::TokenType::GtEq => 49,
            gust_lexer::token::TokenType::AmpAmp => 50,
            gust_lexer::token::TokenType::PipePipe => 51,
            gust_lexer::token::TokenType::Guard => 27,
            gust_lexer::token::TokenType::Import => 28,
            gust_lexer::token::TokenType::Mut => 29,
            gust_lexer::token::TokenType::Func => 30,
            gust_lexer::token::TokenType::Defer => 31,
            gust_lexer::token::TokenType::Move => 32,
            gust_lexer::token::TokenType::Take => 33,
            gust_lexer::token::TokenType::While => 34,
            gust_lexer::token::TokenType::If => 35,
            gust_lexer::token::TokenType::Else => 36,
            gust_lexer::token::TokenType::As => 37,
            gust_lexer::token::TokenType::Unsafe => 38,
            gust_lexer::token::TokenType::Type => 39,
            gust_lexer::token::TokenType::Struct => 40,
            gust_lexer::token::TokenType::Enum => 41,
            gust_lexer::token::TokenType::Match => 42,
            gust_lexer::token::TokenType::Return => 43,
            gust_lexer::token::TokenType::Empty => 44,
            gust_lexer::token::TokenType::Bool => 45,
            gust_lexer::token::TokenType::True => 46,
            gust_lexer::token::TokenType::False => 47,
        };

        out.push_str(&format!("{}\n", tag));
        out.push_str(&format!("{}\n", tok.literal));

        if tok.token_type == gust_lexer::token::TokenType::Eof {
            break;
        }
    }
    out
}

#[test]
fn test_e2e_self_hosted_module_resolver() {
    gust_lexer::init_logging();
    let temp_dir = std::env::temp_dir().join("gust_e2e_self_hosted_resolver");
    let _ = std::fs::remove_dir_all(&temp_dir);
    std::fs::create_dir_all(&temp_dir).unwrap();

    let token_src =
        std::fs::read_to_string("compiler/token.gst").expect("compiler/token.gst missing");
    let lexer_src =
        std::fs::read_to_string("compiler/lexer.gst").expect("compiler/lexer.gst missing");
    let ast_src = std::fs::read_to_string("compiler/ast.gst").expect("compiler/ast.gst missing");
    let mut errors_src =
        std::fs::read_to_string("compiler/errors.gst").expect("compiler/errors.gst missing");
    let resolver_src =
        std::fs::read_to_string("compiler/resolver.gst").expect("compiler/resolver.gst missing");

    if errors_src.contains("type CompilerError struct") {
        errors_src = errors_src.replace(
            "type CompilerError struct",
            "type CompilerError[ctx] struct",
        );
    } else if errors_src.contains("type CompilerError  struct") {
        errors_src = errors_src.replace(
            "type CompilerError  struct",
            "type CompilerError[ctx] struct",
        );
    }
    if errors_src.contains("Index[CompilerError, ctx]") {
        errors_src = errors_src.replace(
            "Index[CompilerError, ctx]",
            "Index[CompilerError[ctx], ctx]",
        );
    }

    let token_path = temp_dir.join("token.gst");
    let lexer_path = temp_dir.join("lexer.gst");
    let ast_path = temp_dir.join("ast.gst");
    let errors_path = temp_dir.join("errors.gst");
    let resolver_path = temp_dir.join("resolver.gst");
    let entry_path = temp_dir.join("resolver_e2e_entry.gst");

    std::fs::write(&token_path, &token_src).unwrap();
    std::fs::write(&lexer_path, &lexer_src).unwrap();
    std::fs::write(&ast_path, &ast_src).unwrap();
    std::fs::write(&errors_path, &errors_src).unwrap();
    std::fs::write(&resolver_path, &resolver_src).unwrap();

    // Create target codebase inside temp_dir
    let target_dir = temp_dir.join("target_codebase");
    std::fs::create_dir_all(target_dir.join("nested")).unwrap();

    let main_gst = target_dir.join("main.gst");
    let lib_gst = target_dir.join("lib.gst");
    let deep_gst = target_dir.join("nested/deep.gst");

    std::fs::write(
        &main_gst,
        "import \"lib.gst\";\nimport \"nested/deep.gst\";\nfunc main() {}",
    )
    .unwrap();
    std::fs::write(&lib_gst, "import \"nested/deep.gst\";\nfunc helper() {}").unwrap();
    std::fs::write(&deep_gst, "func deep_helper() {}").unwrap();

    // entry file that uses our self-hosted resolver to resolve target_codebase/main.gst
    let entry_source = format!(
        "\n        import \"resolver.gst\" as resolver;\n        func main() {{\n            mut ctx := os.Arena.New();\n            defer ctx.Free();\n            os.SetThreadScratch(ctx);\n            \n            mut graph: std.Graph[str, ctx] := std.GraphNew(ctx);\n            mut path_to_node: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);\n            \n            resolver.resolve_imports_recursive({:?}, &graph, &path_to_node, ctx);\n            \n            mut order := resolver.resolve_topological_sort({:?}, &graph, &path_to_node, ctx);\n            \n            os.LogInt(len(order));\n            mut i := 0;\n            while i < len(order) {{\n                os.LogStr(order[i]);\n                i = i + 1;\n            }}\n        }}\n        ",
        main_gst.to_string_lossy(),
        main_gst.to_string_lossy()
    );

    std::fs::write(&entry_path, &entry_source).unwrap();

    // Compile using Rust prototype resolver and typechecker
    let rust_resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let res = rust_resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, mut modules) = res.unwrap();
    let mut checker = TypeChecker::new();
    for path in &order {
        if let Some(module) = modules.get(path) {
            let stem = path.file_stem().unwrap().to_str().unwrap();
            let is_entry = path == order.last().unwrap();
            let prefix = if is_entry {
                "".to_string()
            } else {
                format!("{}__", stem)
            };
            let check_res = checker.check_module(&module.program, &prefix);
            assert!(
                check_res.is_ok(),
                "Typechecking failed on {:?}: {:?}",
                path,
                check_res.err()
            );
        }
    }

    let mut modules_for_codegen = Vec::new();
    for path in &order {
        if let Some(module) = modules.get_mut(path) {
            modules_for_codegen.push((path.clone(), module.program.clone()));
        }
    }

    let codegen = Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
        checker.enum_registry,
        checker.resolved_names,
        checker.resolved_types,
    );
    let c_code = codegen.generate(&modules_for_codegen);

    let count = 8888;
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let c_filename = format!(
        "gust_e2e_resolver_{:?}_{}_{}.c",
        thread_id, process_id, count
    );
    let bin_filename = format!(
        "gust_e2e_resolver_{:?}_{}_{}.bin",
        thread_id, process_id, count
    );

    let c_path = std::env::temp_dir().join(&c_filename);
    let bin_path = std::env::temp_dir().join(&bin_filename);

    std::fs::write(&c_path, &c_code).expect("Failed to write temporary C file");

    let cc_compiler = std::env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let mut cmd = std::process::Command::new(&cc_compiler);
    cmd.arg(&c_path);
    if std::env::var("GUST_NO_SANITIZERS").is_err() {
        cmd.arg("-fsanitize=address,undefined");
    }
    let compile_output = cmd
        .arg("-o")
        .arg(&bin_path)
        .output()
        .expect("GCC command failed");

    assert!(
        compile_output.status.success(),
        "Compilation failed: {}",
        String::from_utf8_lossy(&compile_output.stderr)
    );

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    // Clean up temporary files
    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_dir_all(temp_dir);

    assert!(run_output.status.success());
    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    let expected_output = format!(
        "3\n{}\n{}\n{}",
        deep_gst.to_string_lossy(),
        lib_gst.to_string_lossy(),
        main_gst.to_string_lossy()
    );

    assert_eq!(stdout_str.trim(), expected_output.trim());
}

#[test]
fn test_e2e_logical_and_or_operators() {
    let source = "
        func evaluate_rhs(count: *int, return_val: bool) bool {
            unsafe {
                *count = *count + 1;
            }
            return return_val;
        }
        func main() {
            mut side_effect_count := 0;
            
            // Test 1: && short-circuiting
            mut r1 := false && evaluate_rhs(&side_effect_count, true);
            os.LogInt(side_effect_count);
            
            // Test 2: && non-short-circuiting
            mut r2 := true && evaluate_rhs(&side_effect_count, true);
            os.LogInt(side_effect_count);
            
            // Test 3: || short-circuiting
            mut r3 := true || evaluate_rhs(&side_effect_count, true);
            os.LogInt(side_effect_count);
            
            // Test 4: || non-short-circuiting
            mut r4 := false || evaluate_rhs(&side_effect_count, true);
            os.LogInt(side_effect_count);
            
            // Test 5: Combining operators with comparisons
    // Test 5: Combining operators with comparisons
            mut x := 10;
            mut y := 20;
            if x < 15 && y > 15 {
                os.LogInt(100);
            } else {
                os.LogInt(0);
            }
        }
    ";
    run_e2e_test(source, "0\n1\n1\n2\n100");
}

#[test]
fn test_e2e_canonicalized_namespacing_compilation() {
    use std::fs;
    let temp_dir = std::env::temp_dir().join("gust_e2e_namespaced_isolation");
    fs::create_dir_all(&temp_dir).unwrap();

    let main_path = temp_dir.join("main.gst");
    let lib_path = temp_dir.join("lib.gst");

    let lib_source = "
        type Helper struct {
            value: int
        }
        type MyTemplate[T] struct {
            item: T,
            helper_field: Helper
        }
    ";

    let main_source = "
        import \"lib.gst\" as lib;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            
            mut x: lib.MyTemplate[int];
            x.item = 42;
            x.helper_field.value = 100;
            
            os.LogInt(x.item);
            os.LogInt(x.helper_field.value);
        }
    ";

    fs::write(&lib_path, lib_source).expect("Failed to write lib.gst");
    fs::write(&main_path, main_source).expect("Failed to write main.gst");

    use gust_lexer::resolver::{ModuleResolver, RealFileSystem};
    let resolver = ModuleResolver::new();
    let fs_impl = RealFileSystem;
    let res = resolver.resolve(&main_path, &fs_impl);
    assert!(res.is_ok());
    let (order, mut modules) = res.unwrap();

    let mut checker = TypeChecker::new();
    for path in &order {
        if let Some(module) = modules.get_mut(path) {
            let stem = path.file_stem().unwrap().to_str().unwrap();
            let is_entry = path == order.last().unwrap();
            let prefix = if is_entry {
                "".to_string()
            } else {
                format!("{}__", stem)
            };
            let check_res = checker.check_module(&module.program, &prefix);
            assert!(check_res.is_ok());
        }
    }

    let mut modules_for_codegen = Vec::new();
    for path in &order {
        if let Some(module) = modules.get_mut(path) {
            modules_for_codegen.push((path.clone(), module.program.clone()));
        }
    }

    let codegen = Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
        checker.enum_registry,
        checker.resolved_names,
        checker.resolved_types,
    );
    let c_code = codegen.generate(&modules_for_codegen);

    // Verify transpiled structures exist and are named correctly
    assert!(c_code.contains("struct lib__MyTemplate_int {"));
    assert!(c_code.contains("struct lib__Helper {"));

    // Write to disk and compile E2E using system cc
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let count = TEST_COUNTER.fetch_add(1, std::sync::atomic::Ordering::SeqCst);

    let c_filename = format!(
        "gust_e2e_isolation_{:?}_{}_{}.c",
        thread_id, process_id, count
    );
    let bin_filename = format!(
        "gust_e2e_isolation_{:?}_{}_{}.bin",
        thread_id, process_id, count
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    fs::write(&c_path, &c_code).expect("Failed to write temporary C file");

    let cc_compiler = std::env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let mut cmd = Command::new(&cc_compiler);
    cmd.arg(&c_path);
    if std::env::var("GUST_NO_SANITIZERS").is_err() {
        cmd.arg("-fsanitize=address,undefined");
    }
    let compile_output = cmd.arg("-o").arg(&bin_path).output();

    let compile_success = match compile_output {
        Ok(output) => {
            if !output.status.success() {
                println!("--- GCC Compilation Failed ---");
                println!("STDOUT:\n{}", String::from_utf8_lossy(&output.stdout));
                println!("STDERR:\n{}", String::from_utf8_lossy(&output.stderr));
            }
            output.status.success()
        }
        Err(e) => {
            let _ = fs::remove_file(&c_path);
            let _ = fs::remove_file(&main_path);
            let _ = fs::remove_file(&lib_path);
            let _ = fs::remove_dir(temp_dir);
            panic!("CC failed: {:?}", e);
        }
    };
    assert!(
        compile_success,
        "C compilation of cross-module template namespacing isolation failed!"
    );

    let run_output = Command::new(&bin_path).output().expect("Execution failed");
    let stdout_str =
        String::from_utf8(run_output.stdout).expect("Captured output is not valid UTF-8");

    let _ = fs::remove_file(&c_path);
    let _ = fs::remove_file(&bin_path);
    let _ = fs::remove_file(&main_path);
    let _ = fs::remove_file(&lib_path);
    let _ = fs::remove_dir(temp_dir);

    assert_eq!(stdout_str.trim(), "42\n100");
}

#[test]
fn test_self_hosted_parser_ast_dump() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/ast_dump_entry.gst");

    // Create compiler directory if it doesn't exist
    std::fs::create_dir_all("compiler").unwrap();

    // Write the entry program for the bootstrapped AST dumper
    let entry_source = r#"
        import "token.gst" as token;
        import "lexer.gst" as lexer;
        import "parser.gst" as parser;
        import "ast.gst" as ast;

        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            os.SetThreadScratch(ctx);

            mut args := os.Args(ctx);
            if len(args) < 2 {
                os.LogStr("Usage: ast_dump <file>");
                os.Exit(1);
            }
            mut file_path := args[1];
            mut source := os.ReadFile(ctx, file_path);
            if len(source) == 0 {
                os.LogStr("Error: empty file or failed to read");
                os.Exit(1);
            }

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, source);

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            mut prog := parser.parse_program(&p, ctx);
            mut serialized := ast.serialize_program(&prog, 0, ctx);
            os.LogStr(serialized);
        }
    "#;
    std::fs::write(&entry_path, entry_source).unwrap();

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, mut modules) = res.unwrap();

    let mut checker = gust_lexer::typechecker::TypeChecker::new();
    for path in &order {
        if let Some(module) = modules.get(path) {
            let stem = path.file_stem().unwrap().to_str().unwrap();
            let is_entry = path == order.last().unwrap();
            let prefix = if is_entry {
                "".to_string()
            } else {
                format!("{}__", stem)
            };
            let check_res = checker.check_module(&module.program, &prefix);
            assert!(
                check_res.is_ok(),
                "Typechecking failed on {:?}: {:?}",
                path,
                check_res.err()
            );
        }
    }

    let mut modules_for_codegen = Vec::new();
    for path in &order {
        if let Some(module) = modules.get_mut(path) {
            modules_for_codegen.push((path.clone(), module.program.clone()));
        }
    }

    let codegen = Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
        checker.enum_registry,
        checker.resolved_names,
        checker.resolved_types,
    );
    let c_output = codegen.generate(&modules_for_codegen);

    let temp_dir = std::env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let count = 99999;

    let c_filename = format!("gust_ast_dump_{:?}_{}_{}.c", thread_id, process_id, count);
    let bin_filename = format!("gust_ast_dump_{:?}_{}_{}.bin", thread_id, process_id, count);

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    let cc_compiler = std::env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let mut cmd = Command::new(&cc_compiler);
    cmd.arg(&c_path);
    if std::env::var("GUST_NO_SANITIZERS").is_err() {
        cmd.arg("-fsanitize=address,undefined");
    }
    let compile_output = cmd
        .arg("-o")
        .arg(&bin_path)
        .output()
        .expect("GCC compile command failed");

    if !compile_output.status.success() {
        println!("--- GCC Compilation Failed ---");
        println!(
            "STDOUT:\n{}",
            String::from_utf8_lossy(&compile_output.stdout)
        );
        println!(
            "STDERR:\n{}",
            String::from_utf8_lossy(&compile_output.stderr)
        );
    }
    assert!(
        compile_output.status.success(),
        "C compilation of self-hosted parser/dumper failed"
    );

    // Perform validation on both compiler/token.gst and compiler/errors.gst
    let target_files = vec!["compiler/token.gst", "compiler/errors.gst"];
    for target in target_files {
        // 1. Capture bootstrapped AST serialization
        let run_output = Command::new(&bin_path)
            .arg(target)
            .output()
            .expect("Failed to execute bootstrapped AST dumper");

        assert!(
            run_output.status.success(),
            "Bootstrapped binary failed on {}",
            target
        );
        let bootstrapped_stdout =
            String::from_utf8(run_output.stdout).expect("Invalid UTF-8 output");

        // 2. Capture Rust prototype AST serialization
        let rust_res = resolver
            .resolve(std::path::Path::new(target), &fs_impl)
            .unwrap();
        let entry_module = rust_res.1.get(rust_res.0.last().unwrap()).unwrap();
        let expected_stdout = entry_module.program.serialize(0);

        // 3. Compare byte-by-byte (whitespace trimmed)
        assert_eq!(
            bootstrapped_stdout.trim(),
            expected_stdout.trim(),
            "Byte-by-byte AST dump mismatch on {}",
            target
        );
    }

    // Clean up temporary files
    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_file(entry_path);
}

#[test]
fn test_e2e_self_hosted_scope_resolution() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/typechecker_scope_test_entry.gst");

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, mut modules) = res.unwrap();
    let mut checker = TypeChecker::new();
    for path in &order {
        if let Some(module) = modules.get(path) {
            let stem = path.file_stem().unwrap().to_str().unwrap();
            let is_entry = path == order.last().unwrap();
            let prefix = if is_entry {
                "".to_string()
            } else {
                format!("{}__", stem)
            };
            let check_res = checker.check_module(&module.program, &prefix);
            assert!(
                check_res.is_ok(),
                "Typechecking failed on {:?}: {:?}",
                path,
                check_res.err()
            );
        }
    }

    let mut modules_for_codegen = Vec::new();
    for path in &order {
        if let Some(module) = modules.get_mut(path) {
            modules_for_codegen.push((path.clone(), module.program.clone()));
        }
    }

    let codegen = Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
        checker.enum_registry,
        checker.resolved_names,
        checker.resolved_types,
    );
    let c_output = codegen.generate(&modules_for_codegen);

    let temp_dir = std::env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let c_filename = format!("gust_e2e_scope_{:?}_{}.c", thread_id, process_id);
    let bin_filename = format!("gust_e2e_scope_{:?}_{}.bin", thread_id, process_id);

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    let cc_compiler = std::env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let mut cmd = std::process::Command::new(&cc_compiler);
    cmd.arg(&c_path);
    if std::env::var("GUST_NO_SANITIZERS").is_err() {
        cmd.arg("-fsanitize=address,undefined");
    }
    let compile_output = cmd
        .arg("-o")
        .arg(&bin_path)
        .output()
        .expect("GCC command failed");

    assert!(
        compile_output.status.success(),
        "Compilation failed: {}",
        String::from_utf8_lossy(&compile_output.stderr)
    );

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);

    assert_eq!(stdout_str.trim(), "0\n3\n1\n2");
}

#[test]
fn test_e2e_self_hosted_registries() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/typechecker_registry_test_entry.gst");

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, mut modules) = res.unwrap();
    let mut checker = TypeChecker::new();
    for path in &order {
        if let Some(module) = modules.get(path) {
            let stem = path.file_stem().unwrap().to_str().unwrap();
            let is_entry = path == order.last().unwrap();
            let prefix = if is_entry {
                "".to_string()
            } else {
                format!("{}__", stem)
            };
            let check_res = checker.check_module(&module.program, &prefix);
            assert!(
                check_res.is_ok(),
                "Typechecking failed on {:?}: {:?}",
                path,
                check_res.err()
            );
        }
    }

    let mut modules_for_codegen = Vec::new();
    for path in &order {
        if let Some(module) = modules.get_mut(path) {
            modules_for_codegen.push((path.clone(), module.program.clone()));
        }
    }

    let codegen = Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
        checker.enum_registry,
        checker.resolved_names,
        checker.resolved_types,
    );
    let c_output = codegen.generate(&modules_for_codegen);

    let temp_dir = std::env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let c_filename = format!(
        "gust_e2e_registry_{:?}_{}.c",
        thread_id, process_id
    );
    let bin_filename = format!(
        "gust_e2e_registry_{:?}_{}.bin",
        thread_id, process_id
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    let cc_compiler = std::env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let mut cmd = std::process::Command::new(&cc_compiler);
    cmd.arg(&c_path);
    if std::env::var("GUST_NO_SANITIZERS").is_err() {
        cmd.arg("-fsanitize=address,undefined");
    }
    let compile_output = cmd
        .arg("-o")
        .arg(&bin_path)
        .output() 
        .expect("GCC command failed");

    assert!(
        compile_output.status.success(),
        "Compilation failed: {}",
        String::from_utf8_lossy(&compile_output.stderr)
    );

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);

    assert_eq!(
        stdout_str.trim(),
        "lib__Helper\nlib__add\nmain__local_var\nint\nLookupResult_lib__Helper"
    );
}
