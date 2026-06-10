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
    let cc_compiler = env::var("CC").unwrap_or_else(|_| "cc".to_string());
    let compile_output = Command::new(&cc_compiler)
        .arg(&c_path)
        .arg("-o")
        .arg(&bin_path)
        .output();

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
                cc_compiler,
                e
            );
        }
    };

    if !compile_success.0 {
        let stderr_str = String::from_utf8_lossy(&compile_success.1.stderr);
        let _ = fs::remove_file(&c_path);
        let _ = fs::remove_file(&bin_path);
        panic!("Compilation of the transpiled C code failed. STDERR:\n{}", stderr_str);
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
            parent: int,
            variables: std.HashMap[str, int, ctx],
            config: std.Rc[SharedConfig, ctx]
        }

        func lookup_variable(pool: *std.Pool[Scope[ctx], ctx], scope_idx: int, name: str) int {
            mut curr := scope_idx;
            while curr != 999999 {
                mut lookup := (*pool)[curr].variables.Get(name);
                if lookup.Ok {
                    return lookup.Val;
                }
                curr = (*pool)[curr].parent;
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
            root.parent = 999999;
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
