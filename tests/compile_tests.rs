use gust_lexer::codegen::Codegen;
use gust_lexer::lexer::Lexer;
use gust_lexer::parser::Parser;
use gust_lexer::typechecker::{TypeChecker, TypeError, TypeErrorKind};

fn check_program(source: &str) -> Result<(), TypeError> {
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    let mut checker = TypeChecker::new();
    checker.check_program(&program)
}

#[test]
fn test_safe_branding_substitution() {
    let source = "
        type Node[ctx] struct { val: int }
        func update(ctx: &Arena, n: Index[Node, ctx]) {
            ctx[n].val = 100;
        }
        func main() {
            mut c := os.Arena.New();
            defer c.Free();
            mut n: Index[Node, c] := os.ArenaAlloc(c);
            update(c, n);
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_safety_double_move_rejected() {
    let source = "
        func main() {
            mut payload := os.MockPayload();
            mut a := move payload;
            mut b := move payload; // Error: payload already moved
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::UseOfMovedVariable);
    assert!(err.message.contains("already been moved"));
}

#[test]
fn test_safety_escape_rejected() {
    let source = "
        type Node[ctx] struct { val: int }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut payload := os.MockPayload();
            mut result := payload as &Node[ctx];
            mut movedPayload := move payload;
            os.LogInt(result.Val.val); // Error: payload invalidated
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::VariableOriginInvalidated);
    assert!(
        err.message
            .contains("cannot be used because its backing origin")
    );
}

#[test]
fn test_brand_lifetime_mismatch_rejected() {
    let source = "
        type CustomNode[ctx] struct { SessionID: int }
        func main() {
            mut ctx1 := os.Arena.New();
            defer ctx1.Free();
            mut ctx2 := os.Arena.New();
            defer ctx2.Free();
            mut node: Index[CustomNode, ctx1] := os.ArenaAlloc(ctx1);
            ctx2[node].SessionID = 42; // Error: Value-Branded Lifetime Violation!
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::BrandLifetimeViolation);
    assert!(err.message.contains("Value-Branded Lifetime Violation"));
}

#[test]
fn test_dangling_index_use_rejected() {
    let source = "
        type CustomNode[ctx] struct { SessionID: int }
        func main() {
            mut ctx := os.Arena.New();
            mut node: Index[CustomNode, ctx] := os.ArenaAlloc(ctx);
            mut movedCtx := move ctx; // Invalidate 'ctx' brand
            os.LogInt(node); // Error: node's allocator 'ctx' has been moved or freed
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::AllocatorMovedOrFreed);
    assert!(
        err.message
            .contains("branding allocator 'ctx' has been moved")
    );
}

#[test]
fn test_take_primitive_rejected() {
    let source = "
        func main() {
            mut val := 42;
            mut taken := take val; // Error: 'take' operator banned on primitive POD types
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TakePrimitiveBanned);
    assert!(
        err.message
            .contains("strictly banned on primitive POD types")
    );
}

#[test]
fn test_dereference_outside_unsafe_rejected() {
    let source = "
        func main() {
            mut val := 42;
            mut ptr := &val;
            mut deref := *ptr; // Error: Prohibited outside unsafe blocks
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::UnsafeProhibited);
    assert!(
        err.message
            .contains("strictly prohibited outside 'unsafe' blocks")
    );
}

#[test]
fn test_dereference_inside_unsafe_accepted() {
    let source = "
        func main() {
            mut val := 42;
            mut ptr := &val;
            unsafe {
                mut deref := *ptr; // OK: Accepted inside unsafe block
            }
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_string_view_type_safety_accepted() {
    let source = "
        func main() {
            mut msg := \"Hello Arena\";
            os.LogStr(msg);
            os.LogInt(len(msg));
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_string_view_logint_rejected() {
    let source = "
        func main() {
            mut msg := \"Hello\";
            os.LogInt(msg); // Error: expects Int/Byte but got Str
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TypeMismatch);
    assert!(err.message.contains("os.LogInt expects an Int/Byte"));
}

// === NEW PRESSURE TESTS FOR PHASE 1 SET-BASED ORIGIN TRACKING ===

#[test]
fn test_conditional_origin_union_rejected() {
    let source = "
        func main() {
            mut temp1 := os.MockPayload();
            mut temp2 := os.MockPayload();
            mut view := temp1;
            
            mut cond := 1;
            if cond {
                view = temp1;
            } else {
                view = temp2;
            }
            
            // Move temp2
            mut moved := move temp2;
            
            // view has merged origins {temp1, temp2}. Since temp2 was moved, using view is an error!
            os.LogInt(view[0]); 
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::VariableOriginInvalidated);
    assert!(
        err.message
            .contains("cannot be used because its backing origin")
    );
}

#[test]
fn test_function_view_origin_propagation_rejected() {
    let source = "
        func choose_payload(cond: int, a: []byte, b: []byte) []byte {
            if cond {
                return a;
            } else {
                return b;
            }
        }
        
        func main() {
            mut p1 := os.MockPayload();
            mut p2 := os.MockPayload();
            
            mut result := choose_payload(1, p1, p2);
            
            // Move p1
            mut moved := move p1;
            
            // Since result's origin is union of p1 and p2, moving p1 invalidates result!
            os.LogInt(result[0]);
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::VariableOriginInvalidated);
    assert!(
        err.message
            .contains("cannot be used because its backing origin")
    );
}

// === VALUE-BRANDED VECTOR & HASHMAP COMPILE TIME TESTS ===

#[test]
fn test_branded_vector_safety_rejected() {
    let source = "
        type Node[ctx] struct { val: int }
        func main() {
            mut ctx1 := os.Arena.New();
            defer ctx1.Free();
            mut ctx2 := os.Arena.New();
            defer ctx2.Free();

            mut vec: Vector[Index[Node, ctx1], ctx1] := os.VectorNew(ctx1);
            mut n: Index[Node, ctx1] := os.ArenaAlloc(ctx1);
            vec.Push(n);

            ctx2[vec[0]].val = 100; // Error: Value-Branded Lifetime Violation!
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::BrandLifetimeViolation);
    assert!(err.message.contains("Value-Branded Lifetime Violation"));
}

#[test]
fn test_dangling_vector_use_rejected() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            mut vec: Vector[int, ctx] := os.VectorNew(ctx);
            mut movedCtx := move ctx;
            vec.Push(10); // Error: vec's allocator 'ctx' has been moved or freed
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::AllocatorMovedOrFreed);
    assert!(
        err.message
            .contains("branding allocator 'ctx' has been moved")
    );
}

#[test]
fn test_branded_hashmap_safety_rejected() {
    let source = "
        type Node[ctx] struct { val: int }
        func main() {
            mut ctx1 := os.Arena.New();
            defer ctx1.Free();
            mut ctx2 := os.Arena.New();
            defer ctx2.Free();

            mut map: HashMap[int, Index[Node, ctx1], ctx1] := os.HashMapNew(ctx1);
            mut n: Index[Node, ctx1] := os.ArenaAlloc(ctx1);
            map.Insert(1, n);

            ctx2[map[1]].val = 100; // Error: Value-Branded Lifetime Violation!
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::BrandLifetimeViolation);
    assert!(err.message.contains("Value-Branded Lifetime Violation"));
}

// === VALUE-BRANDED ENUM & PATTERN MATCH COMPILE TIME TESTS ===

#[test]
fn test_adt_match_type_safety_accepted() {
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
                    return 0;
                }
            }
        }

        func main() {
            mut s: Shape;
            s.tag = 0;
            s.Circle.radius = 42;
            os.LogInt(process(s));
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_adt_match_non_exhaustive_rejected() {
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
                Point => {
                    return 0;
                }
            } // Error: Match is not exhaustive (missing Rectangle)
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TypeMismatch);
    assert!(err.message.contains("is not exhaustive"));
}

#[test]
fn test_adt_match_invalid_variant_rejected() {
    let source = "
        type Shape enum {
            Circle { radius: int },
            Point
        }

        func process(shape: Shape) int {
            match shape {
                Circle => {
                    return shape.Circle.radius;
                }
                Point => {
                    return 0;
                }
                Triangle => { // Error: Triangle is not a variant of Shape
                    return 3;
                }
            }
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TypeMismatch);
    assert!(err.message.contains("is not a valid variant of enum"));
}

// === NATIVE FILE I/O TYPE SAFETY COMPILE TIME TESTS ===

#[test]
fn test_file_io_type_safety_accepted() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut path := \"test_input.txt\";
            mut contents := \"Hello File I/O\";
            mut success := os.WriteFile(path, contents);
            
            mut read_back := os.ReadFile(ctx, path);
            os.LogStr(read_back);
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_fallible_lookup_type_checking() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
            mut lookup := map.Get(42);

            mut ok := lookup.Ok;
            mut val := lookup.Val;
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_lookup_result_c_codegen_emission() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
            mut lookup := map.Get(42);
        }
    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    let mut checker = TypeChecker::new();
    let check_res = checker.check_program(&program);
    assert!(check_res.is_ok());

    let codegen = Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
        checker.enum_registry,
    );
    let c_output = codegen.generate(&program);

    // Verify that LookupResult_int is defined as a struct
    assert!(c_output.contains("struct LookupResult_int"));
    // Verify that it contains Ok and Val fields
    assert!(c_output.contains("int Ok;"));
    assert!(c_output.contains("int Val;"));
    // Verify that os_HashMapContains is referenced/generated
    assert!(c_output.contains("os_HashMapContains"));
}

#[test]
fn test_tuple_assignment_rejected() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
            // Tuple assignments are strictly not supported by Gust syntax
            val, ok := map.Get(42); 
        }
    ";
    // Parsing/checking this program should fail to typecheck/compile due to invalid syntactic form
    assert!(check_program(source).is_err());
}

#[test]
fn test_malformed_empty_intrinsic_rejected() {
    let source = "
        func main() {
            mut val := empty(int); // Error: should be empty[int]
        }
    ";
    assert!(check_program(source).is_err());
}

#[test]
fn test_empty_intrinsic_type_checking() {
    let source_valid = "
        type CustomNode struct {
            SessionID: int
        }
        func main() {
            mut val1: int := empty[int];
            mut val2: CustomNode := empty[CustomNode];
        }
    ";
    assert!(check_program(source_valid).is_ok());

    let source_invalid_primitive = "
        func main() {
            mut val: Arena := empty[int]; // Type mismatch: Arena vs Int
        }
    ";
    let res = check_program(source_invalid_primitive);
    assert!(res.is_err());

    let source_invalid_struct = "
        type CustomNode struct {
            SessionID: int
        }
        func main() {
            mut val: CustomNode := empty[int]; // Type mismatch
        }
    ";
    let res2 = check_program(source_invalid_struct);
    assert!(res2.is_err());
    assert_eq!(res2.unwrap_err().kind, TypeErrorKind::TypeMismatch);
}

#[test]
fn test_synthesized_is_valid_type_checking() {
    let source_valid = "
        type StatusPacket struct {
            ID: int,
            Active: byte
        }
        func main() {
            mut val: StatusPacket;
            mut is_ok := StatusPacket_IsValid(&val);
            mut check: int := is_ok;
        }
    ";
    assert!(check_program(source_valid).is_ok());

    let source_invalid_type = "
        type StatusPacket struct {
            ID: int,
            Active: byte
        }
        func main() {
            mut val: StatusPacket;
            mut is_ok := StatusPacket_IsValid(val); // Error: expected pointer &val, got val
        }
    ";
    assert!(check_program(source_invalid_type).is_err());
}

#[test]
fn test_codegen_synthesized_is_valid() {
    let source = "
        type StatusPacket struct {
            ID: int,
            Active: byte
        }
        type NestedPacket struct {
            Status: StatusPacket,
            Enabled: byte,
            Value: int
        }
        func main() {
            mut val: NestedPacket;
        }
    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    let mut checker = TypeChecker::new();
    let check_res = checker.check_program(&program);
    assert!(check_res.is_ok());

    let codegen = Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
        checker.enum_registry,
    );
    let c_output = codegen.generate(&program);

    // Verify that both StatusPacket_IsValid and NestedPacket_IsValid are synthesized
    assert!(c_output.contains("int StatusPacket_IsValid(const StatusPacket* req)"));
    assert!(c_output.contains("int NestedPacket_IsValid(const NestedPacket* req)"));

    // Verify correct recursive field check in NestedPacket_IsValid
    assert!(c_output.contains("if (!StatusPacket_IsValid(&req->Status)) return 0;"));
    // Verify standard byte checks
    assert!(c_output.contains("if (req->Active != 0x00 && req->Active != 0x01) return 0;"));
    assert!(c_output.contains("if (req->Enabled != 0x00 && req->Enabled != 0x01) return 0;"));
}
