use gust_lexer::codegen::Codegen;
use gust_lexer::lexer::Lexer;
use gust_lexer::parser::Parser;
use gust_lexer::typechecker::{TypeChecker, TypeError, TypeErrorKind, Type};

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
            if result.Ok {
                os.LogInt(result.Val.val); // Error: payload invalidated
            }
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
            if lookup.Ok {
                mut val := lookup.Val;
            }
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

// === NEW UNIT TESTS FOR STEP 1: DEFINITE CHECK RULE SCOPING ===

#[test]
fn test_checked_results_scoping() {
    let source = "
        type CustomNode[connCtx] struct {
            SessionID: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut payload := os.MockPayload();
            mut result := payload as &CustomNode[ctx];
            if result.Ok {
                // Consequence block
            } else {
                // Else block
            }
        }
    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    let mut checker = TypeChecker::new();

    // Check program is valid
    assert!(checker.check_program(&program).is_ok());

    // Verify that after checking the program, 'result' is not in the checked_results map (no leaks out of if statement)
    assert!(!checker.checked_results.contains("result"));
}

#[test]
fn test_checked_results_manual_inspection() {
    let mut checker = TypeChecker::new();

    // Manually register variables in the symbol table so we can check Statement::If
    checker.insert_symbol(
        "result".to_string(),
        gust_lexer::typechecker::Type::Struct("CastResult_CustomNode".to_string(), None),
    );

    // Construct If condition: result.Ok == 1
    let cond = gust_lexer::ast::Expression::Binary {
        op: "==".to_string(),
        left: Box::new(gust_lexer::ast::Expression::Selector {
            left: Box::new(gust_lexer::ast::Expression::Identifier(
                "result".to_string(),
            )),
            right: "Ok".to_string(),
        }),
        right: Box::new(gust_lexer::ast::Expression::Integer(1)),
    };

    // Construct consequence block containing dummy statement
    let consequence = gust_lexer::ast::BlockStatement {
        statements: vec![gust_lexer::ast::Statement::Expression(
            gust_lexer::ast::Expression::Integer(1),
        )],
    };

    // Construct If statement
    let if_stmt = gust_lexer::ast::Statement::If {
        condition: cond,
        consequence,
        alternative: Some(gust_lexer::ast::BlockStatement {
            statements: vec![gust_lexer::ast::Statement::Expression(
                gust_lexer::ast::Expression::Integer(2),
            )],
        }),
    };

    // Initially empty
    assert!(checker.checked_results.is_empty());

    // Check statement
    let res = checker.check_statement(&if_stmt);
    assert!(res.is_ok());

    // Verified scope cleanup (the state did not leak)
    assert!(checker.checked_results.is_empty());
}

// === NEW UNIT TESTS FOR STEP 2: DEFINITE CHECK RULE ON SELECTORS ===

#[test]
fn test_definite_check_cast_result_outside_if_rejected() {
    let source = "
        type CustomNode struct {
            SessionID: int
        }
        func main() {
            mut payload := os.MockPayload();
            mut result := payload as &CustomNode;
            os.LogInt(result.Val.SessionID); // Error: result is unchecked
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TypeMismatch);
    assert!(
        err.message
            .contains("Accessing the .Val payload of an unchecked result wrapper")
    );
}

#[test]
fn test_definite_check_lookup_result_outside_if_rejected() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
            mut lookup := map.Get(42);
            os.LogInt(lookup.Val); // Error: lookup is unchecked
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TypeMismatch);
    assert!(
        err.message
            .contains("Accessing the .Val payload of an unchecked result wrapper")
    );
}

#[test]
fn test_definite_check_inside_else_rejected() {
    let source = "
        type CustomNode struct {
            SessionID: int
        }
        func main() {
            mut payload := os.MockPayload();
            mut result := payload as &CustomNode;
            if result.Ok {
                os.LogInt(result.Val.SessionID); // OK
            } else {
                os.LogInt(result.Val.SessionID); // Error: unchecked in else branch
            }
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TypeMismatch);
    assert!(
        err.message
            .contains("Accessing the .Val payload of an unchecked result wrapper")
    );
}

#[test]
fn test_definite_check_inside_if_accepted() {
    let source = "
        type CustomNode struct {
            SessionID: int
        }
        func main() {
            mut payload := os.MockPayload();
            mut result := payload as &CustomNode;
            if result.Ok {
                os.LogInt(result.Val.SessionID); // OK: result is checked
            }
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_definite_check_lookup_inside_if_accepted() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
            mut lookup := map.Get(42);
            if lookup.Ok {
                os.LogInt(lookup.Val); // OK: lookup is checked
            }
        }
    ";
    assert!(check_program(source).is_ok());
}

// === NEW PRESSURE TESTS FOR STEP 3: NESTED STRUCTURES & COMPLEX SCOPING ===

#[test]
fn test_nested_scoping_definite_checks_accepted() {
    let source = "
        type InnerNode struct {
            val: int
        }
        type OuterNode struct {
            inner: LookupResult_InnerNode
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut map: HashMap[int, OuterNode, ctx] := os.HashMapNew(ctx);
            mut outer := map.Get(42);
            if outer.Ok {
                if outer.Val.inner.Ok {
                    os.LogInt(outer.Val.inner.Val.val); // OK: outer and outer.Val.inner are checked
                }
            }
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_nested_scoping_definite_checks_rejected() {
    let source = "
        type InnerNode struct {
            val: int
        }
        type OuterNode struct {
            inner: LookupResult_InnerNode
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut map: HashMap[int, OuterNode, ctx] := os.HashMapNew(ctx);
            mut outer := map.Get(42);
            if outer.Ok {
                // Error: outer.Val.inner is accessed without checking outer.Val.inner.Ok
                os.LogInt(outer.Val.inner.Val.val); 
            }
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TypeMismatch);
    assert!(
        err.message.contains(
            "Accessing the .Val payload of an unchecked result wrapper 'outer.Val.inner'"
        )
    );
}

#[test]
fn test_small_enum_variant_payload_accepted() {
    let source = "
        type Small struct {
            x: int,
            y: int
        }
        type MyEnum enum {
            VariantA { val: Small },
            VariantB
        }
        func main() {
            mut e: MyEnum;
            e.tag = 0;
            e.VariantA.val.x = 42;
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_large_enum_variant_payload_rejected() {
    let source = "
        type Large struct {
            x: int,
            y: int,
            z: int
        }
        type MyEnum enum {
            VariantA { val: Large },
            VariantB
        }
        func main() {
            mut e: MyEnum;
            e.tag = 0;
            e.VariantA.val.x = 42;
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::LargeEnumVariantPayload);
    assert!(err.message.contains("large enum variant payload"));
}

#[test]
fn test_large_enum_variant_indirection_accepted() {
    let source = "
        type Large struct {
            x: int,
            y: int,
            z: int
        }
        type MyEnum[ctx] enum {
            VariantA { val: Index[Large, ctx] },
            VariantB
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_pod_struct_propagation_recognized_as_copyable() {
    let source = "
        type MyPod struct {
            a: int,
            b: int
        }
    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    let mut checker = TypeChecker::new();
    assert!(checker.check_program(&program).is_ok());

    let pod_type = Type::Struct("MyPod".to_string(), None);
    assert!(!checker.is_linear(&pod_type));
}

#[test]
fn test_linear_struct_propagation_recognized_as_linear() { 
    let source = "
        type MyLinear struct {
            ptr: *int,
            id: int
        }
    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    let mut checker = TypeChecker::new();
    assert!(checker.check_program(&program).is_ok());

    let linear_type = Type::Struct("MyLinear".to_string(), None);
    assert!(checker.is_linear(&linear_type));
}

#[test]
fn test_move_pod_type_does_not_invalidate() {
    let source = "
        type MyPod struct {
            x: int,
            y: int
        }
        func main() {
            mut p: MyPod;
            p.x = 10;
            p.y = 20;

            mut p2 := move p; // Move POD struct

            // Should be perfectly fine to read p again since it is a copyable POD!
            os.LogInt(p.x); 
            
            mut a := 42;
            mut b := move a; // Move primitive int
            os.LogInt(a); // Should be fine to read again
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_move_linear_type_invalidates() {
    let source = "
        type MyLinear struct {
            ptr: *int
        }
        func main() {
            mut p: MyLinear;
            mut p2 := move p; // Move Linear struct

            // Should fail because p contains a Linear field and is now invalidated
            mut err := p.ptr; 
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::UseOfMovedVariable);
}

#[test]
fn test_monomorphized_pod_collection_is_copyable() {
    let source = "
        type Wrapper[T] struct {
            val: T
        }
        func main() {
            mut w1: Wrapper[int];
            w1.val = 42;

            mut w2 := move w1; // Since T is int, Wrapper[int] is POD and copyable!
            os.LogInt(w1.val); // Should be fine to read again
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_monomorphized_linear_collection_is_linear() {
    let source = "
        type Wrapper[T] struct {
            val: T
        }
        func main() {
            mut w1: Wrapper[*int];
            mut w2 := move w1; // Wrapper[*int] is Linear!
            mut err := w1.val; // Error: w1 was moved
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::UseOfMovedVariable);
}

#[test]
fn test_generic_definition_enforces_strict_linear_safety() {
    let source = "
        type Holder[T] struct {
            val: T
        }
        func process(h: Holder[T]) {
            mut h2 := move h;
            mut y := h.val; // Error: h is conservatively treated as Linear and is moved!
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::UseOfMovedVariable);
}

#[test]
fn test_monomorphized_pod_move_generates_no_cleanup() {
    let source = "
        type MyPod struct {
            x: int,
            y: int
        }
        func main() {
            mut p1: MyPod;
            p1.x = 10;
            mut p2 := move p1;
        }
    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    let mut checker = TypeChecker::new();
    assert!(checker.check_program(&program).is_ok());

    let codegen = Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
        checker.enum_registry,
    );
    let c_code = codegen.generate(&program);

    // Assert that the generated C code contains the assignment but NO memset or cleanups for the move!
    assert!(!c_code.contains("memset"));
}

#[test]
fn test_monomorphized_linear_move_generates_cleanup() {
    let source = "
        type MyLinear struct {
            ptr: *int
        }
        func main() {
            mut p1: MyLinear;
            mut p2 := move p1;
        }
    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    let mut checker = TypeChecker::new();
    assert!(checker.check_program(&program).is_ok());

    let codegen = Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
        checker.enum_registry,
    );
    let c_code = codegen.generate(&program);

    // Assert that the generated C code contains memset for the Linear struct move!
    assert!(c_code.contains("memset"));
}

#[test]
fn test_pod_enum_propagation_recognized_as_copyable() {
    let source = "
        type MyPod struct {
            x: int,
            y: int
        }
        type PodEnum enum {
            VariantA { val: MyPod },
            VariantB
        }
    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    let mut checker = TypeChecker::new();
    assert!(checker.check_program(&program).is_ok());

    let enum_type = Type::Struct("PodEnum".to_string(), None);
    assert!(!checker.is_linear(&enum_type));
}

#[test]
fn test_linear_enum_propagation_recognized_as_linear() {
    let source = "
        type MyLinear struct {
            ptr: *int
        }
        type LinearEnum enum {
            VariantA { val: MyLinear },
            VariantB
        }
    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    let mut checker = TypeChecker::new();
    assert!(checker.check_program(&program).is_ok());

    let enum_type = Type::Struct("LinearEnum".to_string(), None);
    assert!(checker.is_linear(&enum_type));
}

#[test]
fn test_deep_nested_linear_propagation() {
    let source = "
        type MyLinear struct {
            ptr: *int
        }
        type NestedEnum enum {
            VariantA { val: MyLinear },
            VariantB
        }
        type OuterPod struct {
            id: int,
            payload: NestedEnum
        }
    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    let mut checker = TypeChecker::new();
    assert!(checker.check_program(&program).is_ok());

    let outer_type = Type::Struct("OuterPod".to_string(), None);
    assert!(checker.is_linear(&outer_type));
}

#[test]
fn test_move_propagated_linear_struct_invalidates() {
    let source = "
        type MyLinear struct {
            ptr: *int
        }
        type NestedEnum enum {
            VariantA { val: MyLinear },
            VariantB
        }
        type OuterPod struct {
            id: int,
            payload: NestedEnum
        }
        func main() {
            mut o: OuterPod;
            o.id = 42;

            mut o2 := move o; // o is recursively Linear because of NestedEnum and MyLinear!

            // Attempting to read o.id after the move should fail because o is moved!
            os.LogInt(o.id);
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::UseOfMovedVariable);
}

#[test]
fn test_move_propagated_linear_enum_invalidates() {
    let source = "
        type MyLinear struct {
            ptr: *int
        }
        type LinearEnum enum {
            VariantA { val: MyLinear },
            VariantB
        }
        func main() {
            mut e: LinearEnum;
            e.tag = 0;

            mut e2 := move e; // e is recursively Linear!

            // Attempting to read e.tag after move should fail because e is moved!
            os.LogInt(e.tag);
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::UseOfMovedVariable);
}

#[test]
fn test_uninitialized_inout_parameter_rejected() {
    let source = "
        type Node struct {
            val: int
        }
        func process(p: *Node) {
            mut x := move p; // Move the pointer parameter p
            return; // Error: p was moved but not re-initialized before return
        } 
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::UseOfMovedVariable);
    assert!(err.message.contains("was moved but never re-initialized"));
}

#[test]
fn test_reinitialized_inout_parameter_accepted() {
    let source = "
        type Node struct {
            val: int
        }
        func process(p: *Node) {
            mut x := move p;
            p = empty[*Node]; // Re-initialize p using empty[T]
            return; // Accepted!
        } 
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_take_pod_struct_accepted() {
    let source = "
        type MyPod struct {
            x: int,
            y: int
        }
        func main() {
            mut p: MyPod;
            p.x = 10;
            mut taken := take p; // Accepted on custom structs
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_take_linear_struct_accepted() {
    let source = "
        type MyLinear struct {
            ptr: *int
        }
        func main() {
            mut p: MyLinear;
            unsafe {
                p.ptr = &10;
            }
            mut taken := take p; // Accepted on Linear struct
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_monomorphized_take_codegen() {
    let source = "
        type MyPod struct {
            x: int,
            y: int
        }
        type MyLinear struct {
            ptr: *int
        }
        func main() {
            mut p1: MyPod;
            p1.x = 10;
            mut p2 := take p1; // should emit no memset/cleanup

            mut l1: MyLinear;
            mut l2 := take l1; // should emit memset
        }
    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    let mut checker = TypeChecker::new();
    assert!(checker.check_program(&program).is_ok());

    let codegen = Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
        checker.enum_registry,
    );
    let c_code = codegen.generate(&program);

    // Assert that C code contains memset for l1 but not for p1
    assert!(c_code.contains("memset(&l1"));
    assert!(!c_code.contains("memset(&p1"));
}

#[test]
fn test_sentinel_null_codegen_structure() {
    let source = "
        type Node struct {
            val: int,
            ptr: *int,
            next: Index[Node, ctx]
        }
        func main() {
            mut n: Node;
        }
    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    let mut checker = TypeChecker::new();
    assert!(checker.check_program(&program).is_ok());

    let codegen = Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
        checker.enum_registry,
    );
    let init_str = codegen.gen_type_aware_initializer(&Type::Struct("Node".to_string(), None));
    
    // Assert that the generated initializer contains correct field-by-field initializations
    assert!(init_str.contains(".next = 0xFFFFFFFF"));
    assert!(init_str.contains(".ptr = NULL"));
    assert!(init_str.contains(".val = 0"));
    assert_eq!(init_str, "((Node){ .next = 0xFFFFFFFF, .ptr = NULL, .val = 0 })");
}

#[test]
fn test_type_aware_vardecl_codegen_structure() {
    let source = "
        type Node struct {
            val: int,
            ptr: *int,
            next: Index[Node, ctx]
        }
        func main() {
            mut n: Node;
        }
    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    let mut checker = TypeChecker::new();
    assert!(checker.check_program(&program).is_ok());

    let codegen = Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
        checker.enum_registry,
    );
    let c_code = codegen.generate(&program);

    // Verify that Node n is initialized using gen_type_aware_initializer, not blind {0}
    assert!(c_code.contains("Node n = ((Node){ .next = 0xFFFFFFFF, .ptr = NULL, .val = 0 });"));
}

#[test]
fn test_unbranded_struct_containing_slice_rejected() {
    let source = "
        type Packet struct {
            id: int,
            data: []byte
        }
        func main() {}
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::BrandLifetimeViolation);
    assert!(err.message.contains("cannot contain ephemeral slice or view"));
}

#[test]
fn test_unbranded_struct_containing_str_rejected() {
    let source = "
        type User struct {
            name: str
        }
        func main() {}
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::BrandLifetimeViolation);
    assert!(err.message.contains("cannot contain ephemeral slice or view"));
}

#[test]
fn test_branded_struct_containing_slice_accepted() {
    let source = "
        type CustomNode[ctx] struct {
            name: str,
            data: []byte
        }
        func main() {}
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_unbranded_generic_instantiated_with_view_rejected() {
    let source = "
        type Holder[T] struct {
            val: T
        }
        func main() {
            mut h: Holder[str]; // Error: unbranded monomorphization with str (view)
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::BrandLifetimeViolation);
    assert!(err.message.contains("cannot contain ephemeral slice or view"));
}

#[test]
fn test_branded_generic_instantiated_with_view_accepted() {
    let source = "
        type Holder[T, ctx] struct {
            val: T
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut h: Holder[str, ctx]; // Accepted: branded generic
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_nested_different_brands_rejected() {
    let source = "
        func main() {
            mut innerCtx := os.Arena.New();
            defer innerCtx.Free();
            mut outerCtx := os.Arena.New();
            defer outerCtx.Free();

            // Vector[Vector[str, innerCtx], outerCtx]
            mut vec: Vector[Vector[str, innerCtx], outerCtx] := os.VectorNew(outerCtx);
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::BrandLifetimeViolation);
    assert!(err.message.contains("Mismatched nested brand"));
}

#[test]
fn test_identical_nested_brands_accepted() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            // Vector[Vector[str, ctx], ctx]
            mut vec: Vector[Vector[str, ctx], ctx] := os.VectorNew(ctx);
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_return_local_variable_view_rejected() {
    let source = "
        func leak() str {
            mut local := \"hello\";
            return local; // Error: escape analysis violation
        }
        func main() {}
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::BrandLifetimeViolation);
    assert!(err.message.contains("Escape analysis violation"));
}

#[test]
fn test_return_parameter_view_accepted() {
    let source = "
        func pass(p: str) str {
            return p; // OK: parameter view is safe to return (lifespan determined down-stack)
        }
        func main() {}
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_return_static_literal_view_accepted() {
    let source = "
        func constant() str {
            return \"Hello\"; // OK: static read-only view is safe to return
        }
        func main() {}
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_view_invalidated_on_parent_reassignment() {
    let source = "
        func main() {
            mut temp := os.MockPayload();
            mut view := temp;
            
            temp = os.MockPayload(); // Reassignment of parent
            
            os.LogInt(view[0]); // Error: view is invalidated because temp was modified!
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::VariableOriginInvalidated);
    assert!(err.message.contains("backing origin"));
}

#[test]
fn test_view_invalidated_on_parent_field_mutation() {
    let source = "
        type Packet struct {
            val: int
        }
        func main() {
            mut payload: Packet;
            payload.val = 42;
            
            mut view := &payload;
            
            payload.val = 100; // Mutating a field of the backing payload
            
            unsafe {
                os.LogInt((*view).val); // Error: view is invalidated because payload was mutated!
            }
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::VariableOriginInvalidated);
    assert!(err.message.contains("backing origin"));
}

#[test]
fn test_function_call_union_origins_invalidation() {
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
            
            p1 = os.MockPayload(); // Reassigning/modifying one of the parent inputs!
            
            os.LogInt(result[0]); // Error: result is invalidated because its parent origin p1 was modified!
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
