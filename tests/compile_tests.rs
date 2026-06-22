use gust_lexer::codegen::Codegen;
mod common;
use gust_lexer::lexer::Lexer;
use gust_lexer::parser::Parser;
use gust_lexer::typechecker::{Type, TypeChecker, TypeError, TypeErrorKind};
use std::env;


fn filter_output_c_code(stdout: &str) -> String {
    stdout
        .lines()
        .filter(|l| {
            let trimmed = l.trim_start();
            if trimmed.is_empty() {
                return true;
            }
            trimmed.chars().next().map_or(false, |c| c.is_ascii())
        })
        .collect::<Vec<_>>()
        .join("\n")
}
fn map_message_to_kind(msg: &str) -> TypeErrorKind {
    if msg.contains("ParserError") || msg.contains("Syntax Error") {
        TypeErrorKind::SyntaxError
    } else if msg.contains("large enum variant payload") {
        TypeErrorKind::LargeEnumVariantPayload
    } else if msg.contains("backing origin") || msg.contains("origin invalidated") {
        TypeErrorKind::VariableOriginInvalidated
    } else if msg.contains("Allocator moved or freed") {
        TypeErrorKind::AllocatorMovedOrFreed
    } else if msg.contains("Value-Branded Lifetime Violation") || msg.contains("escape") || msg.contains("Escape") || msg.contains("scratchpad-allocated") || msg.contains("must be cleanly closed") || msg.contains("cannot be moved while open") || msg.contains("Brand Nesting") || msg.contains("Mismatched nested brand") || msg.contains("preventing safe handoff") || msg.contains("Thread-safety") || msg.contains("cannot contain ephemeral slice or view") {
        TypeErrorKind::BrandLifetimeViolation
    } else if msg.contains("already been moved") || msg.contains("Use of moved variable") || msg.contains("moved") {
        TypeErrorKind::UseOfMovedVariable
    } else if msg.contains("strictly banned on primitive") {
        TypeErrorKind::TakePrimitiveBanned
    } else if msg.contains("prohibited outside 'unsafe' blocks") || msg.contains("prohibited outside unsafe blocks") {
        TypeErrorKind::UnsafeProhibited
    } else if msg.contains("Template") && msg.contains("expects") && msg.contains("generic arguments") {
        TypeErrorKind::TemplateArgumentMismatch
    } else if (msg.contains("expects") || msg.contains("expected")) && msg.contains("arguments") || msg.contains("must accept exactly") {
        TypeErrorKind::ArgumentMismatch
    } else if msg.contains("Undefined variable") {
        TypeErrorKind::UndefinedVariable
    } else if msg.contains("strictly not supported") {
        TypeErrorKind::SyntaxError
    } else if msg.contains("duplicate function definition") || msg.contains("Duplicate function definition") {
        TypeErrorKind::DuplicateFunctionDefinition
    } else if msg.contains("not found on struct layout") || (msg.contains("Field") && msg.contains("not found")) {
        TypeErrorKind::FieldNotFound
    } else if msg.contains("Method") && msg.contains("not found") {
        TypeErrorKind::MethodNotFound
    } else if msg.contains("Undefined function") {
        TypeErrorKind::UndefinedFunction
    } else if msg.contains("Unresolved namespace alias") || msg.contains("mismatch") || msg.contains("is not exhaustive") || msg.contains("is not a valid variant") || msg.contains("mismatched") || msg.contains("expects") || msg.contains("mismatch") {
        TypeErrorKind::TypeMismatch
    } else {
        TypeErrorKind::TypeMismatch
    }
}

fn check_program(source: &str) -> Result<(), TypeError> {
    let compiler_path = common::get_compiled_compiler();
    let temp_dir = env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let time = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let filename = format!("gust_compile_test_{:?}_{}_{}.gst", thread_id, process_id, time);
    let file_path = temp_dir.join(filename);

    std::fs::write(&file_path, source).expect("Failed to write temporary test file");

    let output = std::process::Command::new(compiler_path)
        .arg(&file_path)
        .output()
        .expect("Failed to run self-hosted compiler");

    let _ = std::fs::remove_file(&file_path);

    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    let combined_output = format!("{}\n{}", stdout, stderr);

    eprintln!("\n--- DEBUG check_program execution ---");
    eprintln!("STATUS: {:?}", output.status);
    eprintln!("STDOUT:\n{}", stdout);
    eprintln!("STDERR:\n{}", stderr);
    eprintln!("--------------------------------------\n");

    if output.status.success() {
        Ok(())
    } else {
        let mut error_message = String::new();
        let mut line_num = 1;
        let mut col_num = 1;
        let mut found_span = false;

        // Try to parse: "TypeError at line 5:26:" or "❌ TypeError at line 5:26:"
        for line in combined_output.lines() {
            if let Some(idx) = line.find("TypeError at line ") {
                let rest = &line[idx + "TypeError at line ".len()..];
                if let Some(colon_idx) = rest.find(':') {
                    let line_str = &rest[..colon_idx];
                    let rest2 = &rest[colon_idx + 1..];
                    if let Some(space_idx) = rest2.find(':') {
                        let col_str = &rest2[..space_idx];
                        if let (Ok(l), Ok(c)) = (line_str.parse::<usize>(), col_str.parse::<usize>()) {
                            line_num = l;
                            col_num = c;
                            found_span = true;
                            
                            let raw_msg = rest2[space_idx + 1..].trim();
                            if !raw_msg.is_empty() {
                                error_message = raw_msg.to_string();
                            }
                            break;
                        }
                    }
                } 
            }
        }

        if !found_span {
            let lines: Vec<&str> = combined_output.lines().collect();
            for i in 0..lines.len() { 
                if lines[i].contains("ParserError in file:") {
                    if i + 4 < lines.len() {
                        error_message = lines[i + 2].trim().to_string();
                        if let (Ok(l), Ok(c)) = (lines[i + 3].trim().parse::<usize>(), lines[i + 4].trim().parse::<usize>()) {
                            line_num = l;
                            col_num = c;
                            found_span = true;
                        }
                    }
                    break;
                } 
            }
        }

        if error_message.is_empty() {
                for line in combined_output.lines() {
                    let trimmed = line.trim();
                    let first_char = trimmed.chars().next();
                    let is_log = trimmed.is_empty()
                        || first_char == Some('👁')
                        || first_char == Some('❌')
                        || first_char == Some('🗄')
                        || first_char == Some('🔄')
                        || first_char == Some('⚖')
                        || first_char == Some('📥')
                        || first_char == Some('✅')
                        || first_char == Some('⚙')
                        || first_char == Some('🎯')
                        || first_char == Some('🔍')
                        || trimmed.starts_with("DEBUG:")
                        || trimmed.starts_with("---")
                        || trimmed.starts_with("STDOUT:")
                        || trimmed.starts_with("STDERR:");
                    if !is_log {
                        error_message = trimmed.to_string();
                        break;
                    }
                }
            }

        if error_message.is_empty() {
            error_message = "Unknown compilation error".to_string();
        }

        let error_kind = map_message_to_kind(&error_message);

        eprintln!("DEBUG: parsed error_message = {:?}", error_message);
        eprintln!("DEBUG: mapped error_kind = {:?}", error_kind);

        let span = if found_span {
            Some(gust_lexer::token::Span {
                start: gust_lexer::token::Position {
                    line: line_num,
                    column: col_num,
                    offset: 0,
                },
                end: gust_lexer::token::Position {
                    line: line_num,
                    column: col_num,
                    offset: 0,
                },
            })
        } else {
            None
        };

        Err(TypeError {
            kind: error_kind,
            message: error_message,
            span,
        })
    }
}

#[test]
fn test_thread_local_context_registration_valid() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut tl: std.ThreadLocalContext[ctx];
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_thread_local_context_brand_mismatch_rejected() {
    let source = "
        func accept_context(ctx: &Arena, tl: std.ThreadLocalContext[ctx]) {
        }
        func main() {
            mut ctx1 := os.Arena.New();
            defer ctx1.Free();
            mut ctx2 := os.Arena.New();
            defer ctx2.Free();
            
            mut tl: std.ThreadLocalContext[ctx1] := os.GetThreadScratch();
            accept_context(ctx2, tl);
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TypeMismatch);
}

#[test]
fn test_thread_local_context_escape_rejected() {
    let source = "
        func leak() str {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut tl: std.ThreadLocalContext[ctx] := os.GetThreadScratch();
            unsafe {
                mut ptr := tl.arena as []byte;
                mut s := ptr as str;
                return s;
            }
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
fn test_bool_primitive_accepted() {
    let source = "
        func main() {
            mut b: bool := true;
            b = false;
            if b {
                os.LogInt(1);
            }
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_character_classification_and_parsing_type_checking() {
    let source = "
        func main() {
            mut b: byte := 48;
            mut is_digit_val: bool := std.is_digit(b);
            mut is_alpha_val: bool := std.is_alpha(b);
            mut is_whitespace_val: bool := std.is_whitespace(b);

            mut num_str := \"12345\";
            mut num_val: int := std.parse_int(num_str);
        }
    ";
    assert!(check_program(source).is_ok());
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
    assert!(err.message.contains("moved"));
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
    assert_eq!(err.kind, TypeErrorKind::UseOfMovedVariable);
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
    let span = err.span.expect("Expected a span for unsafe dereference");
    assert_eq!(span.start.line, 5);
    assert_eq!(span.start.column, 26);
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
    assert!(err.message.contains("os.LogInt expects an Int/Byte") || err.message.contains("Expected Int but got Str") || err.message.contains("os_LogInt"));
    let span = err.span.expect("Expected a span for logint view error");
    assert_eq!(span.start.line, 4);
    assert!(span.start.column == 13 || span.start.column == 23);
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
    assert_eq!(err.kind, TypeErrorKind::UseOfMovedVariable);
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
        checker.resolved_names,
        checker.resolved_types,
    );
    let modules_for_codegen = vec![(std::path::PathBuf::from("input.gst"), program)];
    let c_output = codegen.generate(&modules_for_codegen);

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
        checker.resolved_names,
        checker.resolved_types,
    );
    let modules_for_codegen = vec![(std::path::PathBuf::from("input.gst"), program)];
    let c_output = codegen.generate(&modules_for_codegen);

    // Verify that both StatusPacket_IsValid and NestedPacket_IsValid are synthesized
    assert!(c_output.contains("int StatusPacket_IsValid(StatusPacket* req)"));
    assert!(c_output.contains("int NestedPacket_IsValid(NestedPacket* req)"));

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
                gust_lexer::token::Span::dummy(),
            )),
            right: "Ok".to_string(),
            span: gust_lexer::token::Span::dummy(),
        }),
        right: Box::new(gust_lexer::ast::Expression::Integer(
            1,
            gust_lexer::token::Span::dummy(),
        )),
        span: gust_lexer::token::Span::dummy(),
    };

    // Construct consequence block containing dummy statement
    let consequence = gust_lexer::ast::BlockStatement {
        statements: vec![gust_lexer::ast::Statement::Expression(
            gust_lexer::ast::Expression::Integer(1, gust_lexer::token::Span::dummy()),
            gust_lexer::token::Span::dummy(),
        )],
        span: gust_lexer::token::Span::dummy(),
    };

    // Construct If statement
    let if_stmt = gust_lexer::ast::Statement::If {
        condition: cond,
        consequence,
        alternative: Some(gust_lexer::ast::BlockStatement {
            statements: vec![gust_lexer::ast::Statement::Expression(
                gust_lexer::ast::Expression::Integer(2, gust_lexer::token::Span::dummy()),
                gust_lexer::token::Span::dummy(),
            )],
            span: gust_lexer::token::Span::dummy(),
        }),
        span: gust_lexer::token::Span::dummy(),
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

#[test]
fn test_definite_check_compound_and_accepted() {
    let source = "
        type CustomNode struct {
            SessionID: int
        }
        func main() {
            mut payload := os.MockPayload();
            mut result := payload as &CustomNode;
            mut cond := true;
            if cond && result.Ok {
                os.LogInt(result.Val.SessionID); // OK: result is checked via &&
            }
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_definite_check_compound_or_rejected() {
    let source = "
        type CustomNode struct {
            SessionID: int
        }
        func main() {
            mut payload := os.MockPayload();
            mut result := payload as &CustomNode;
            mut cond := false;
            if cond || result.Ok {
                os.LogInt(result.Val.SessionID); // Error: result is NOT guaranteed checked via ||
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
fn test_definite_check_nested_scoping_cleanliness() {
    let source = "
        type CustomNode struct {
            SessionID: int
        }
        func main() {
            mut payload := os.MockPayload();
            mut result := payload as &CustomNode;
            mut cond := true;
            if cond {
                if result.Ok {
                    os.LogInt(result.Val.SessionID); // OK: result is checked here
                }
                // Error: result is NOT checked in outer if scope
                os.LogInt(result.Val.SessionID);
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
    let res = check_program(source);
    if let Err(err) = res {
        panic!(
            "test_nested_scoping_definite_checks_accepted FAILED with: {}",
            err.message
        );
    }
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
    if err.kind != TypeErrorKind::TypeMismatch {
        panic!(
            "test_nested_scoping_definite_checks_rejected FAILED with unexpected error: {} (kind: {:?})",
            err.message, err.kind
        );
    }

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

    // Output the full captured diagnostic error string to guarantee visibility
    eprintln!("\\n--- CAPTURED ERROR MESSAGE ---");
    eprintln!("{}", err.message);
    eprintln!("------------------------------\\n");

    assert_eq!(err.kind, TypeErrorKind::LargeEnumVariantPayload);
    assert!(err.message.contains("large enum variant payload"));
    assert!(err.message.contains("VariantA"));
    assert!(err.message.contains("Large"));
    assert!(err.message.contains("3 fields"));
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
        checker.resolved_names,
        checker.resolved_types,
    );
    let modules_for_codegen = vec![(std::path::PathBuf::from("input.gst"), program)];
    let c_code = codegen.generate(&modules_for_codegen);

    // Assert that the generated C code contains the assignment but NO memset or cleanups for the move!
    assert!(!c_code.contains("memset(&p1"));
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
        checker.resolved_names,
        checker.resolved_types,
    );
    let modules_for_codegen = vec![(std::path::PathBuf::from("input.gst"), program)];
    let c_code = codegen.generate(&modules_for_codegen);

    // Assert that the generated C code contains memset for the Linear struct move!
    assert!(c_code.contains("memset(&p1"));
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
        checker.resolved_names,
        checker.resolved_types,
    );
    let modules_for_codegen = vec![(std::path::PathBuf::from("input.gst"), program)];
    let c_code = codegen.generate(&modules_for_codegen);

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
        checker.resolved_names,
        checker.resolved_types,
    );
    let init_str = codegen.gen_type_aware_initializer(&Type::Struct("Node".to_string(), None));

    // Assert that the generated initializer contains correct field-by-field initializations
    assert!(init_str.contains(".next = 0xFFFFFFFF"));
    assert!(init_str.contains(".ptr = NULL"));
    assert!(init_str.contains(".val = 0"));
    assert_eq!(
        init_str,
        "((Node){ .next = 0xFFFFFFFF, .ptr = NULL, .val = 0 })"
    );
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
        checker.resolved_names,
        checker.resolved_types,
    );
    let modules_for_codegen = vec![(std::path::PathBuf::from("input.gst"), program)];
    let c_output = codegen.generate(&modules_for_codegen);

    // Verify that Node n is initialized using gen_type_aware_initializer, not blind {0}
    assert!(c_output.contains("Node n = ((Node){ .next = 0xFFFFFFFF, .ptr = NULL, .val = 0 });"));
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
    assert!(
        err.message
            .contains("cannot contain ephemeral slice or view")
    );
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
    assert!(
        err.message
            .contains("cannot contain ephemeral slice or view")
    );
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
    assert!(
        err.message
            .contains("cannot contain ephemeral slice or view")
    );
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
    assert!(
        err.message.contains("Mismatched nested brand")
            || err.message.contains("Brand Nesting Restriction violation")
    );
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
fn test_unbranded_linear_struct_in_branded_collection_rejected() {
    let source = "
        type MyLinear struct {
            ptr: *int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            // Vector[MyLinear, ctx] is rejected because MyLinear is an unbranded linear struct!
            mut vec: Vector[MyLinear, ctx] := os.VectorNew(ctx);
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::BrandLifetimeViolation);
    assert!(err.message.contains("Brand Nesting Restriction violation"));
}

#[test]
fn test_view_and_pod_in_branded_collection_accepted() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut v1: Vector[str, ctx] := os.VectorNew(ctx); // view is accepted
            mut v2: Vector[int, ctx] := os.VectorNew(ctx); // POD is accepted
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_nested_mismatched_branded_collection_rejected() {
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
    assert!(
        err.message.contains("Mismatched nested brand")
            || err.message.contains("Brand Nesting Restriction violation")
    );
}

#[test]
fn test_handoff_isolation_violation_rejected() {
    let source = "
        type Packet[ctx] struct {
            data: []byte
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut local := os.MockPayload(); // stack variable
            mut p: Packet[ctx];
            p.data = local; // p.data points to thread-local stack payload

            mut movedCtx := move ctx; // Error: Thread-safety violation
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::BrandLifetimeViolation);
    assert!(err.message.contains("preventing safe handoff of arena"));
}

#[test]
fn test_handoff_use_after_move_rejected() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut vec: Vector[int, ctx] := os.VectorNew(ctx);
            vec.Push(10);

            mut movedCtx := move ctx; // Invalidate ctx and vec

            vec.Push(20); // Error: use of moved variable vec
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::UseOfMovedVariable);
}

#[test]
fn test_handoff_safe_accepted() {
    let source = "
        type Packet[ctx] struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut p: Packet[ctx];
            p.val = 42;

            mut movedCtx := move ctx; // Safe: no stack references
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
    assert_eq!(err.kind, TypeErrorKind::UseOfMovedVariable);
    assert!(err.message.contains("Use of moved variable"));
}

#[test]
fn test_view_invalidated_on_parent_field_mutation() {
    let source = "
        type Packet[ctx] struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut payload: Packet[ctx];
            payload.val = 42;
            
            mut view := &payload;
            
            payload.val = 100; // Mutating a field of the backing payload
            
            unsafe {
                mut deref := *view;
                os.LogInt(deref.val); // Error: view is invalidated because payload was mutated!
            }
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::UseOfMovedVariable);
    assert!(err.message.contains("Use of moved variable"));
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
    assert_eq!(err.kind, TypeErrorKind::UseOfMovedVariable);
    assert!(err.message.contains("Use of moved variable"));
}

#[test]
fn test_namespaced_monomorphization() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut v: std.Vector[int, ctx] := os.VectorNew(ctx);
            mut m: std.HashMap[int, int, ctx] := os.HashMapNew(ctx);
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_brand_erasure_utility_functions() {
    let source = "
        type Node[ctx] struct {
            name: str
        }
        func process(s: str) int {
            return std.str_eq(s, \"test\");
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut n: Index[Node, ctx] := os.ArenaAlloc(ctx);
            ctx[n].name = \"hello\";
            
            // Extract view from branded collection
            mut res := process(ctx[n].name);
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_pool_type_checking_valid() {
    let source = "
        type Node struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut pool: std.Pool[Node, ctx] := std.PoolNew(ctx);
            mut item: Node;
            item.val = 42;

            mut idx := pool.Alloc(item);
            pool.Free(idx);
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_pool_type_checking_invalid() {
    let source_mismatch_alloc = "
        type Node struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut pool: std.Pool[Node, ctx] := std.PoolNew(ctx);
            mut idx := pool.Alloc(42);
        }
    ";
    let res1 = check_program(source_mismatch_alloc);
    assert!(res1.is_err());
    let err1 = res1.unwrap_err();
    assert_eq!(err1.kind, TypeErrorKind::TypeMismatch);

    let source_invalid_free = "
        type Node struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut pool: std.Pool[Node, ctx] := std.PoolNew(ctx);
            pool.Free(42);
        }
    ";
    let res2 = check_program(source_invalid_free);
    assert!(res2.is_err());
    let err2 = res2.unwrap_err();
    assert_eq!(err2.kind, TypeErrorKind::TypeMismatch);
}

#[test]
fn test_brand_crossing_cloning() {
    let source = "
        type Node[ctx] struct { val: int }
        func main() {
            mut ctx1 := os.Arena.New();
            defer ctx1.Free();
            mut ctx2 := os.Arena.New();
            defer ctx2.Free();

            mut n1: Index[Node, ctx1] := os.ArenaAlloc(ctx1);
            ctx1[n1].val = 42;

            // Direct assignment should still fail (this would fail if uncommented)
            // mut n2_err: Index[Node, ctx2] := n1; 

            // Cloning with std.Clone should succeed!
            mut n2: Index[Node, ctx2] := std.Clone(ctx2, n1);
            ctx2[n2].val = 100;
        }
    ";
    assert!(check_program(source).is_ok());

    let source_invalid = "
        type Node[ctx] struct { val: int }
        func main() {
            mut ctx1 := os.Arena.New();
            defer ctx1.Free();
            mut ctx2 := os.Arena.New();
            defer ctx2.Free();

            mut n1: Index[Node, ctx1] := os.ArenaAlloc(ctx1);
            
            // Direct assignment across different brands must be rejected!
            mut n2: Index[Node, ctx2] := n1; 
        }
    ";
    let res = check_program(source_invalid);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TypeMismatch);
}

#[test]
fn test_rc_and_graph_type_checking_valid() {
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

            mut rc: std.Rc[Node, ctx] := std.RcNew(&pool, item);
            mut cloned_rc := rc.Clone();
            
            unsafe {
                mut val_ptr := rc.Get();
                os.LogInt((*val_ptr).val);
            }

            cloned_rc.Release();
            rc.Release();

            mut graph: std.Graph[Node, ctx] := std.GraphNew(ctx);
            mut n1 := graph.AddNode(item);
            mut n2 := graph.AddNode(item);
            graph.AddEdge(n1, n2);

            unsafe {
                mut val_ptr2 := graph.GetNode(n1);
                os.LogInt((*val_ptr2).val);
            }
        }
    ";
    let res = check_program(source);
    if let Err(ref e) = res {
        eprintln!("test_rc_and_graph_type_checking_valid failed with: {:?}", e);
    }
    assert!(res.is_ok());
}

#[test]
fn test_rc_and_graph_type_checking_invalid() {
    let source_brand_violation_rc = "
        type Node struct {
            val: int
        }
        func main() {
            mut ctx1 := os.Arena.New();
            defer ctx1.Free();
            mut ctx2 := os.Arena.New();
            defer ctx2.Free();

            mut pool1: std.Pool[std.RcNode[Node], ctx1] := std.PoolNew(ctx1);
            mut item: Node;

            mut rc: std.Rc[Node, ctx2] := std.RcNew(&pool1, item); 
        }
    ";
    let res1 = check_program(source_brand_violation_rc);
    assert!(res1.is_err());
    let err1 = res1.unwrap_err();
    assert_eq!(err1.kind, TypeErrorKind::TypeMismatch);
    let span1 = err1.span.expect("Expected a span for Rc brand mismatch");
    assert_eq!(
        span1.start.line, 14,
        "Rc brand mismatch line: expected 14, got {}, error: {:?}",
        span1.start.line, err1
    );
    assert_eq!(
        span1.start.column, 43,
        "Rc brand mismatch column: expected 43, got {}, error: {:?}",
        span1.start.column, err1
    );

    let source_non_int_graph = "
        type Node struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut graph: std.Graph[Node, ctx] := std.GraphNew(ctx);
            mut item: Node;
            mut n1 := graph.AddNode(item);

            graph.AddEdge(n1, \"not_an_int\");
        }
    ";
    let res3 = check_program(source_non_int_graph);
    assert!(res3.is_err());
    let err3 = res3.unwrap_err();
    assert_eq!(err3.kind, TypeErrorKind::TypeMismatch);
    let span3 = err3.span.expect("Expected a span for non-int graph edge");
    assert_eq!(
        span3.start.line, 13,
        "Non-int graph edge line: expected 13, got {}, error: {:?}",
        span3.start.line, err3
    );
    assert_eq!(
        span3.start.column, 31,
        "Non-int graph edge column: expected 31, got {}, error: {:?}",
        span3.start.column, err3
    );
}

#[test]
fn test_diagnostic_formatting_layout() {
    let source = "func main() {\n    mut val := 42;\n    mut taken := take val;\n}";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    let mut checker = TypeChecker::new();
    let res = checker.check_program(&program);
    assert!(res.is_err());
    let err = res.unwrap_err();
    let diag = gust_lexer::typechecker::format_diagnostic(source, &err);

    // Assert diagnostic layout contains coordinate header
    assert!(diag.contains("[line 3:18]"));
    // Assert line number prefix
    assert!(diag.contains("3 |     mut taken := take val;"));
    // Assert caret line aligned to take val
    assert!(diag.contains("     |                  ^^^^^^^^"));
    // Assert error message
    assert!(diag.contains("Error:"));
}

#[test]
fn test_multiple_syntax_errors_diagnostic_reporting() {
    let source = "\n        type MyStruct struct {\n            field1: \n        }\n        func main() {\n            mut a := ;\n        }\n    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let _program = parser.parse_program();

    assert_eq!(parser.errors.len(), 2);

    // Verify first syntax error is for field type signature
    let err1 = &parser.errors[0];
    assert_eq!(err1.kind, TypeErrorKind::SyntaxError);
    assert!(err1.message.contains("Expected field type signature"));
    assert_eq!(err1.span.unwrap().start.line, 4);

    // Verify second syntax error is for missing expression
    let err2 = &parser.errors[1];
    assert_eq!(err2.kind, TypeErrorKind::SyntaxError);
    assert!(err2.message.contains("Expected expression after ':='"));
    assert_eq!(err2.span.unwrap().start.line, 6);

    // Verify format_diagnostic doesn't panic and produces correct layout
    let diag1 = gust_lexer::typechecker::format_diagnostic(source, err1);
    assert!(diag1.contains("[line 4:"));
    assert!(diag1.contains("Expected field type signature"));
}

#[test]
fn test_multi_file_compilation_success() {
    use std::fs;
    let temp_dir = std::env::temp_dir().join("gust_test_multi");
    fs::create_dir_all(&temp_dir).unwrap();

    let main_path = temp_dir.join("main.gst");
    let lib_path = temp_dir.join("lib.gst");

    fs::write(&main_path, "import \"lib.gst\"; func main() { helper(); }").unwrap();
    fs::write(&lib_path, "func helper() {}").unwrap();

    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let res = resolver.resolve(&main_path, &fs_impl);
    assert!(res.is_ok());

    let (order, mut modules) = res.unwrap();
    assert_eq!(order.len(), 2);

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

    let mut checker = gust_lexer::typechecker::TypeChecker::new();
    let check_res = checker.check_program(&program);
    assert!(check_res.is_ok());

    let _ = fs::remove_file(main_path);
    let _ = fs::remove_file(lib_path);
    let _ = fs::remove_dir(temp_dir);
}

// #[test]
// fn test_self_hosted_import_scanner_debug() {
//     let lexer_content = std::fs::read_to_string("compiler/lexer.gst").unwrap();
//     panic!("LEXER.GST CONTENT:\n{}", lexer_content);
// }

#[test]
fn test_self_hosted_import_scanner_old() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/resolver_test_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = r#"
        import "resolver.gst" as resolver;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            os.SetThreadScratch(ctx);
            
            mut source := "import 'std' as standard; import 'os'; func main() {}";
            
            mut paths := resolver.scan_imports(source, ctx);
            os.LogInt(len(paths));
            os.LogStr(paths[0]);
            os.LogStr(paths[1]);
        }
    "#;
    std::fs::write(&entry_path, entry_source).unwrap();

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

    // Compile and run E2E
    let temp_dir = std::env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let c_filename = format!("gust_e2e_resolver_{:?}_{}_scan.c", thread_id, process_id);
    let bin_filename = format!("gust_e2e_resolver_{:?}_{}_scan.bin", thread_id, process_id);

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    assert_eq!(stdout_str.trim(), "2\nstd\nos");
}

#[test]
fn test_self_hosted_graph_construction() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/graph_test_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    // Create nested mock files
    let temp_dir = std::env::temp_dir().join("gust_graph_test");
    std::fs::create_dir_all(temp_dir.join("nested")).unwrap();

    let main_gst = temp_dir.join("main.gst");
    let lib_gst = temp_dir.join("lib.gst");
    let deep_gst = temp_dir.join("nested/deep.gst");

    std::fs::write(
        &main_gst,
        "import \"lib.gst\";\nimport \"nested/deep.gst\";\nfunc main() {}",
    )
    .unwrap();
    std::fs::write(&lib_gst, "import \"nested/deep.gst\";\nfunc helper() {}").unwrap();
    std::fs::write(&deep_gst, "func deep_helper() {}").unwrap();

    let entry_source = format!(
        "
        import \"resolver.gst\" as resolver;
        func main() {{
            mut ctx := os.Arena.New();
            defer ctx.Free();
            os.SetThreadScratch(ctx);
            
            mut graph: std.Graph[str, ctx] := std.GraphNew(ctx);
            mut path_to_node: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
            
            resolver.resolve_imports_recursive({:?}, &graph, &path_to_node, ctx);
            
            guard main_idx := path_to_node.Get({:?}) else {{
                return;
            }}
            guard lib_idx := path_to_node.Get({:?}) else {{                return;
            }}
            guard deep_idx := path_to_node.Get({:?}) else {{
                return;
            }}
            
            os.LogStr(\"main ok\");
            os.LogStr(\"lib ok\");
            os.LogStr(\"deep ok\");
            
            os.LogInt(graph.nodes.len);
            
            unsafe {{
                mut main_node := &graph.nodes.data[main_idx];
                os.LogInt(len(main_node.edges));
                
                mut target_idx := main_node.edges[0];
                mut name_ptr := graph.GetNode(target_idx);
                os.LogStr(*name_ptr);
            }}
        }}
        ",
        main_gst.to_string_lossy(),
        main_gst.to_string_lossy(),
        lib_gst.to_string_lossy(),
        deep_gst.to_string_lossy()
    );
    std::fs::write(&entry_path, entry_source).unwrap();

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

    // Compile and run E2E
    let temp_out_dir = std::env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let c_filename = format!("gust_e2e_resolver_{:?}_{}_graph.c", thread_id, process_id);
    let bin_filename = format!("gust_e2e_resolver_{:?}_{}_graph.bin", thread_id, process_id);

    let c_path = temp_out_dir.join(&c_filename);
    let bin_path = temp_out_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_file(entry_path);
    let _ = std::fs::remove_dir_all(temp_dir);

    assert!(run_output.status.success());
    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    assert_eq!(
        stdout_str.trim(),
        format!(
            "main ok\nlib ok\ndeep ok\n3\n2\n{}",
            lib_gst.to_string_lossy()
        )
    );
}

#[test]
fn test_self_hosted_topological_sort() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/sort_test_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    // Create nested mock files
    let temp_dir = std::env::temp_dir().join("gust_sort_test");
    std::fs::create_dir_all(temp_dir.join("nested")).unwrap();

    let main_gst = temp_dir.join("main.gst");
    let lib_gst = temp_dir.join("lib.gst");
    let deep_gst = temp_dir.join("nested/deep.gst");

    std::fs::write(
        &main_gst,
        "import \"lib.gst\";\nimport \"nested/deep.gst\";\nfunc main() {}",
    )
    .unwrap();
    std::fs::write(&lib_gst, "import \"nested/deep.gst\";\nfunc helper() {}").unwrap();
    std::fs::write(&deep_gst, "func deep_helper() {}").unwrap();

    let entry_source = format!(
        "
        import \"resolver.gst\" as resolver;
        func main() {{
            mut ctx := os.Arena.New();
            defer ctx.Free();
            os.SetThreadScratch(ctx);
            
            mut graph: std.Graph[str, ctx] := std.GraphNew(ctx);
            mut path_to_node: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
            
            resolver.resolve_imports_recursive({:?}, &graph, &path_to_node, ctx);
            
            mut order := resolver.resolve_topological_sort({:?}, &graph, &path_to_node, ctx);
            
            os.LogInt(len(order));
            mut i := 0;
            while i < len(order) {{
                os.LogStr(order[i]);
                i = i + 1;
            }}
        }}
        ",
        main_gst.to_string_lossy(),
        main_gst.to_string_lossy()
    );
    std::fs::write(&entry_path, entry_source).unwrap();

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

    // Compile and run E2E
    let temp_out_dir = std::env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let c_filename = format!("gust_e2e_resolver_{:?}_{}_sort.c", thread_id, process_id);
    let bin_filename = format!("gust_e2e_resolver_{:?}_{}_sort.bin", thread_id, process_id);

    let c_path = temp_out_dir.join(&c_filename);
    let bin_path = temp_out_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_file(entry_path);
    let _ = std::fs::remove_dir_all(temp_dir);

    assert!(run_output.status.success());
    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    assert_eq!(
        stdout_str.trim(),
        format!(
            "3\n{}\n{}\n{}",
            deep_gst.to_string_lossy(),
            lib_gst.to_string_lossy(),
            main_gst.to_string_lossy()
        )
    );
}

#[test]
fn test_self_hosted_cycle_detection() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/cycle_test_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    // Create nested cyclic mock files
    let temp_dir = std::env::temp_dir().join("gust_cycle_test");
    std::fs::create_dir_all(&temp_dir).unwrap();

    let main_gst = temp_dir.join("main.gst");
    let lib_gst = temp_dir.join("lib.gst");

    // Cycle: main imports lib, lib imports main
    std::fs::write(&main_gst, "import \"lib.gst\";\nfunc main() {}").unwrap();
    std::fs::write(&lib_gst, "import \"main.gst\";\nfunc helper() {}").unwrap();

    let entry_source = format!(
        "
        import \"resolver.gst\" as resolver;
        func main() {{
            mut ctx := os.Arena.New();
            defer ctx.Free();
            os.SetThreadScratch(ctx);
            
            mut graph: std.Graph[str, ctx] := std.GraphNew(ctx);
            mut path_to_node: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
            
            resolver.resolve_imports_recursive({:?}, &graph, &path_to_node, ctx);
            
            resolver.resolve_topological_sort({:?}, &graph, &path_to_node, ctx);
        }}
        ",
        main_gst.to_string_lossy(),
        main_gst.to_string_lossy()
    );
    std::fs::write(&entry_path, entry_source).unwrap();

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

    // Compile and run E2E
    let temp_out_dir = std::env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let c_filename = format!("gust_e2e_resolver_{:?}_{}_cycle.c", thread_id, process_id);
    let bin_filename = format!("gust_e2e_resolver_{:?}_{}_cycle.bin", thread_id, process_id);

    let c_path = temp_out_dir.join(&c_filename);
    let bin_path = temp_out_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_file(entry_path);
    let _ = std::fs::remove_dir_all(temp_dir);

    assert!(!run_output.status.success());
    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");
    assert!(stdout_str.contains("Cyclic dependency detected:"));
}

#[test]
fn test_self_hosted_token_definitions() {
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/token_defs_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    // 1. Valid branded token use
    let entry_source = "
        import \"token.gst\" as token;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            
            mut pos: token.Position;
            pos.line = 10;
            pos.column = 5;
            pos.offset = 120;
            
            mut span: token.Span;
            span.start = pos;
            span.end = pos;
            
            mut tok_type: token.TokenType;
            tok_type.tag = 2;
            
            mut tok: token.Token[ctx];
            tok.token_type = tok_type;
            tok.literal = \"test\";
            tok.span = span;
        }
    ";
    std::fs::write(&entry_path, entry_source).unwrap();

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, modules) = res.unwrap();
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
                "Typechecking failed: {:?}",
                check_res.err()
            );
        }
    }

    // 2. Reject lifetime brand mismatch
    let invalid_entry_source = "
        import \"token.gst\" as token;
        func main() {
            mut ctx1 := os.Arena.New();
            defer ctx1.Free();
            mut ctx2 := os.Arena.New();
            defer ctx2.Free();
            
            mut t1: token.Token[ctx1];
            mut t2: token.Token[ctx2] := t1;
        }
    ";
    std::fs::write(&entry_path, invalid_entry_source).unwrap();

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok());
    let (order, modules) = res.unwrap();
    let mut checker = TypeChecker::new();
    let mut had_error = false;
    for path in &order {
        if let Some(module) = modules.get(path) {
            let stem = path.file_stem().unwrap().to_str().unwrap();
            let is_entry = path == order.last().unwrap();
            let prefix = if is_entry {
                "".to_string()
            } else {
                format!("{}__", stem)
            };
            if checker.check_module(&module.program, &prefix).is_err() {
                had_error = true;
                break;
            }
        }
    }
    assert!(
        had_error,
        "Expected lifetime brand mismatch to be rejected by typechecker"
    );

    let _ = std::fs::remove_file(entry_path);
}

#[test]
fn test_self_hosted_lexer_scaffold() {
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/lexer_scaffold_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = "
        import \"lexer.gst\" as lexer;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            
            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, \"   a\");
            os.LogInt(l.ch as int);
            
            lexer.skip_whitespace(&l);
            os.LogInt(l.ch as int);
        }
    ";
    std::fs::write(&entry_path, entry_source).unwrap();

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, modules) = res.unwrap();
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
                "Typechecking failed: {:?}",
                check_res.err()
            );
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
    let mut modules_for_codegen = Vec::new();
    for path in &order {
        if let Some(module) = modules.get(path) {
            modules_for_codegen.push((path.clone(), module.program.clone()));
        }
    }
    let c_output = codegen.generate(&modules_for_codegen);
    assert!(c_output.contains("struct lexer__Lexer {"));
    assert!(c_output.contains("lexer__read_char("));
    assert!(c_output.contains("lexer__skip_whitespace("));

    let _ = std::fs::remove_file(entry_path);
}

#[test]
fn test_lexer_view_extraction() {
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/lexer_view_extraction_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = "
        import \"lexer.gst\" as lexer;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            
            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, \"identifier 12345 string\");
            
            mut ident: str := lexer.read_identifier(&l);
            lexer.skip_whitespace(&l);
            mut num: str := lexer.read_number(&l);
            lexer.skip_whitespace(&l);
            mut s: str := lexer.read_string(&l);
            
            os.LogStr(ident);
            os.LogStr(num);
            os.LogStr(s);
        }
    ";
    std::fs::write(&entry_path, entry_source).unwrap();

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, modules) = res.unwrap();
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
                "Typechecking failed: {:?}",
                check_res.err()
            );
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
    let mut modules_for_codegen = Vec::new();
    for path in &order {
        if let Some(module) = modules.get(path) {
            modules_for_codegen.push((path.clone(), module.program.clone()));
        }
    }
    let c_output = codegen.generate(&modules_for_codegen);
    assert!(c_output.contains("lexer__read_identifier("));
    assert!(c_output.contains("lexer__read_number("));
    assert!(c_output.contains("lexer__read_string("));
    assert!(c_output.contains("lexer__lookup_ident("));

    let _ = std::fs::remove_file(entry_path);
}

#[test]
fn test_lexer_token_generation() {
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/lexer_token_gen_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = "
        import \"token.gst\" as token;
        import \"lexer.gst\" as lexer;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            
            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, \"mut a := 10;\");
            
            mut t1: token.Token[ctx];
            lexer.next_token(&l, &t1);
            os.LogInt(t1.token_type.tag);
            os.LogStr(t1.literal);
            
            mut t2: token.Token[ctx];
            lexer.next_token(&l, &t2);
            os.LogInt(t2.token_type.tag);
            os.LogStr(t2.literal);
            
            mut t3: token.Token[ctx];
            lexer.next_token(&l, &t3);
            os.LogInt(t3.token_type.tag);
            os.LogStr(t3.literal);
            
            mut t4: token.Token[ctx];
            lexer.next_token(&l, &t4);
            os.LogInt(t4.token_type.tag);
            os.LogStr(t4.literal);
            
            mut t5: token.Token[ctx];
            lexer.next_token(&l, &t5);
            os.LogInt(t5.token_type.tag);
            os.LogStr(t5.literal);
        }
    ";
    std::fs::write(&entry_path, entry_source).unwrap();

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, modules) = res.unwrap();
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
                "Typechecking failed: {:?}",
                check_res.err()
            );
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
    let mut modules_for_codegen = Vec::new();
    for path in &order {
        if let Some(module) = modules.get(path) {
            modules_for_codegen.push((path.clone(), module.program.clone()));
        }
    }
    let c_output = codegen.generate(&modules_for_codegen);
    assert!(c_output.contains("lexer__next_token("));

    let _ = std::fs::remove_file(entry_path);
}

#[test]
fn test_self_hosted_lexer_compilation() {
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/lexer_test_comp_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = "
        import \"token.gst\" as token;
        import \"lexer.gst\" as lexer;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, \"mut a := 10;\");
            mut t: token.Token[ctx];
            lexer.next_token(&l, &t);
        }
    ";
    std::fs::write(&entry_path, entry_source).unwrap();

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, modules) = res.unwrap();
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
    assert!(c_output.contains("struct lexer__Lexer {"));
    assert!(c_output.contains("lexer__next_token("));

    let _ = std::fs::remove_file(entry_path);
}

#[test]
fn test_cli_dump_ast_integration() {
    use std::fs as std_fs;
    use std::process::Command;

    let temp_dir = std::env::temp_dir().join("gust_cli_test_ast");
    std_fs::create_dir_all(&temp_dir).unwrap();
    let file_path = temp_dir.join("test.gst");
    std_fs::write(&file_path, "mut x: int := 42;").unwrap();

    // Robustness: clean up any pre-existing gust_output.c so we can verify early termination
    let c_file = std::path::Path::new("gust_output.c");
    if c_file.exists() {
        let _ = std_fs::remove_file(c_file);
    }

    let output = Command::new("cargo")
        .arg("run")
        .arg("--")
        .arg("--dump-ast")
        .arg(&file_path)
        .output()
        .expect("failed to execute cargo run");

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("Program:"));
    assert!(stdout.contains("VarDecl: x (mut=true) : Int"));
    assert!(stdout.contains("Integer: 42"));

    // Ensure no output C file is written
    assert!(!c_file.exists());

    let _ = std_fs::remove_file(file_path);
    let _ = std_fs::remove_dir(temp_dir);
}

#[test]
fn test_cli_dump_types_integration() {
    use std::fs as std_fs;
    use std::process::Command;

    let temp_dir = std::env::temp_dir().join("gust_cli_test_types");
    std_fs::create_dir_all(&temp_dir).unwrap();
    let file_path = temp_dir.join("test.gst");
    std_fs::write(
        &file_path,
        "type Point struct { x: int, y: int } func main() {}",
    )
    .unwrap();

    // Robustness: clean up any pre-existing gust_output.c so we can verify early termination
    let c_file = std::path::Path::new("gust_output.c");
    if c_file.exists() {
        let _ = std_fs::remove_file(c_file);
    }

    let output = Command::new("cargo")
        .arg("run")
        .arg("--")
        .arg("--dump-types")
        .arg(&file_path)
        .output()
        .expect("failed to execute cargo run");

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("Structures:"));
    assert!(stdout.contains("Point:"));
    assert!(stdout.contains("x : Int"));
    assert!(stdout.contains("y : Int"));

    // Ensure no output C file is written
    assert!(!c_file.exists());

    let _ = std_fs::remove_file(file_path);
    let _ = std_fs::remove_dir(temp_dir);
}

#[test]
fn test_generic_enum_typechecking() {
    let source = "
        type MyResult[T, ctx] enum {
            Ok { val: T },
            Err { val: int }
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut res: MyResult[int, ctx];
            res.tag = 0;
            res.Ok.val = 42;
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_self_hosted_token_compilation() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/token_test_entry.gst");

    // Create compiler directory if it doesn't exist
    std::fs::create_dir_all("compiler").unwrap();

    // Write a dummy entry file that imports the token.gst
    let entry_source = "
        import \"token.gst\" as token;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut t: token.Token[ctx];
            t.token_type.tag = 2;
            t.literal = \"hello\";
        }
    ";
    std::fs::write(&entry_path, entry_source).unwrap();

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, modules) = res.unwrap();

    eprintln!("====================================================");
    eprintln!("🔍 E2E SELF-HOSTED RESOLUTION ORDER:");
    for (idx, path) in order.iter().enumerate() {
        eprintln!("  [{}] {:?}", idx + 1, path);
    }
    eprintln!("====================================================");

    if let Some(entry_module) = modules.get(order.last().unwrap()) {
        eprintln!("📄 ENTRY FILE SOURCE (e2e_test_entry.gst):");
        eprintln!("----------------------------------------------------");
        for (idx, line) in entry_module.source.lines().enumerate() {
            eprintln!("{:4} | {}", idx + 1, line);
        }
        eprintln!("----------------------------------------------------");
    }

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
            match checker.check_module(&module.program, &prefix) {
                Ok(_) => {}
                Err(err) => {
                    let formatted =
                        gust_lexer::typechecker::format_diagnostic(&module.source, &err);
                    eprintln!("{}", formatted);
                    panic!("Typechecking failed on {:?}", path);
                }
            }
        }
    }

    let mut modules_for_codegen = Vec::new();
    for path in &order {
        if let Some(module) = modules.get(path) {
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
    let c_output = codegen.generate(&modules_for_codegen);

    // Verify TokenType is transpiled to a C enum/tags
    assert!(c_output.contains("token__TokenType_Tag__Ident = 2"));
    // Verify Token is transpiled to a C struct utilizing C-level string view components
    assert!(c_output.contains("struct token__Token {"));
    assert!(c_output.contains("Slice_unsigned_char literal;"));

    // Clean up temporary entry file
    let _ = std::fs::remove_file(entry_path);
}

#[test]
fn test_self_hosted_codegen_initializers() {
    std::thread::Builder::new()
        .stack_size(104857600) // 100 MB
        .spawn(|| {
            gust_lexer::init_logging();
            let resolver = gust_lexer::resolver::ModuleResolver::new();
            let fs_impl = gust_lexer::resolver::RealFileSystem;
            let entry_path = std::path::Path::new("compiler/codegen_initializer_test_entry.gst");

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
            let c_filename = format!("gust_e2e_initializers_{:?}_{}.c", thread_id, process_id);
            let bin_filename = format!("gust_e2e_initializers_{:?}_{}.bin", thread_id, process_id);

            let c_path = temp_dir.join(&c_filename);
            let bin_path = temp_dir.join(&bin_filename);

            std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

            common::compile_c_program(&c_path, &bin_path, &c_output);

            let run_output = std::process::Command::new(&bin_path)
                .output()
                .expect("Execution failed");

            let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

            let _ = std::fs::remove_file(&c_path);
            let _ = std::fs::remove_file(&bin_path);

            let filtered_stdout: String = stdout_str
                .lines()
                .filter(|line| {
                    !line.starts_with("🗄️") && !line.starts_with("🔄") && !line.starts_with("👁️")
                })
                .collect::<Vec<_>>()
                .join("\n");

            // Check individual output blocks
            assert!(filtered_stdout.contains("0"));
            assert!(filtered_stdout.contains("0xFFFFFFFF"));
            assert!(filtered_stdout.contains("NULL"));
            assert!(filtered_stdout.contains("((Point){ .x = 0, .y = 0 })"));
            assert!(filtered_stdout.contains("int Node_IsValid(Node* req) {"));
            assert!(
                filtered_stdout
                    .contains("if (req->active != 0x00 && req->active != 0x01) return 0;")
            );
            assert!(filtered_stdout.contains("Topological Sort OK: Inner precedes Outer"));
            assert!(filtered_stdout.contains("Topological Sort ADT OK: Variant precedes Enum"));
            assert!(filtered_stdout.contains("((ast__Program){0})"));
            assert!(filtered_stdout.contains("((MyNode){0})"));
            assert!(filtered_stdout.contains("p_node->val"));
            assert!(filtered_stdout.contains("node.val"));
            assert!(filtered_stdout.contains("((int)os_ArenaAlloc(&ctx, sizeof(ListNode)))"));
            assert!(filtered_stdout.contains("os_GetThreadScratch forward declaration generated correctly!"));
            assert!(filtered_stdout.contains("os_GetThreadScratch function definition generated correctly!"));

            // Check generated C program contains full structure definitions and validation helpers
            assert!(filtered_stdout.contains("typedef struct Node Node;"));
            assert!(filtered_stdout.contains("struct Node {"));
            assert!(filtered_stdout.contains("unsigned char active;"));
            assert!(filtered_stdout.contains("int val;"));
        })
        .unwrap()
        .join()
        .unwrap();
}

#[test]
fn test_e2e_sentinel_verification_self_hosted() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/e2e_sentinel_verification_target.gst");

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
                "Typechecking failed: {:?}",
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
        "gust_e2e_sentinel_self_hosted_{:?}_{}.c",
        thread_id, process_id
    );
    let bin_filename = format!(
        "gust_e2e_sentinel_self_hosted_{:?}_{}.bin",
        thread_id, process_id
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);

    assert_eq!(stdout_str.trim(), "ptr NULL ok\nidx null ok");
}

#[test]
fn test_e2e_recursive_invariant_safety_self_hosted() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/e2e_recursive_invariant_target.gst");

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
                "Typechecking failed: {:?}",
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
        "gust_e2e_invariant_self_hosted_{:?}_{}.c",
        thread_id, process_id
    );
    let bin_filename = format!(
        "gust_e2e_invariant_self_hosted_{:?}_{}.bin",
        thread_id, process_id
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);

    assert_eq!(stdout_str.trim(), "1\n0");
}

#[test]
fn test_e2e_bootstrapped_self_test() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/e2e_bootstrapped_self_target.gst");

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
                "Typechecking failed: {:?}",
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
        "gust_e2e_bootstrapped_self_test_{:?}_{}.c",
        thread_id, process_id
    );
    let bin_filename = format!(
        "gust_e2e_bootstrapped_self_test_{:?}_{}.bin",
        thread_id, process_id
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);

    assert_eq!(stdout_str.trim(), "3\n10\n20\n30\n2\n42\n84");
}

#[test]
fn test_self_hosted_ast_compilation() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/ast_test_entry.gst");

    // Create compiler directory if it doesn't exist
    std::fs::create_dir_all("compiler").unwrap();

    // Write a dummy entry file that imports token.gst and ast.gst
    let entry_source = "
        import \"token.gst\" as token;
        import \"ast.gst\" as ast;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut p: ast.Program[ctx];
            p.statements = os.ArenaAlloc(ctx);

            mut s: ast.Statement[ctx];
            s.tag = 13;
            s.Expression.expr = os.ArenaAlloc(ctx);

            mut e: ast.Expression[ctx];
            e.tag = 1;
            e.Integer.val = 42;
        }
    ";
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

    let codegen = gust_lexer::codegen::Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
        checker.enum_registry,
        checker.resolved_names,
        checker.resolved_types,
    );
    let c_output = codegen.generate(&modules_for_codegen);

    // Verify AST structs and enums are transpiled correctly
    assert!(c_output.contains("struct ast__Program"));
    assert!(c_output.contains("struct ast__Statement {"));
    assert!(c_output.contains("struct ast__Expression {"));
    assert!(c_output.contains("ast__Statement_Tag__Expression = 13"));
    assert!(c_output.contains("ast__Expression_Tag__Integer = 1"));

    // Clean up temporary entry file
    let _ = std::fs::remove_file(entry_path);
}

#[test]
fn test_self_hosted_typechecker_types_compilation() {
    std::thread::Builder::new()
        .stack_size(104857600) // 100 MB
        .spawn(|| {
            gust_lexer::init_logging();
            let resolver = gust_lexer::resolver::ModuleResolver::new();
            let fs_impl = gust_lexer::resolver::RealFileSystem;
            let entry_path = std::path::Path::new("compiler/typechecker_types_test_entry.gst");

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

            assert!(c_output.contains("struct typechecker__StructLayout {"));
            assert!(c_output.contains("struct typechecker__FunctionSignature {"));
        })
        .unwrap()
        .join()
        .unwrap();
}

#[test]
fn test_self_hosted_typechecker_integration() {
    std::thread::Builder::new()
        .stack_size(104857600) // 100 MB
        .spawn(|| {
            gust_lexer::init_logging();
            let resolver = gust_lexer::resolver::ModuleResolver::new();
            let fs_impl = gust_lexer::resolver::RealFileSystem;
            let entry_path = std::path::Path::new("compiler/typechecker_types_test_entry.gst");

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

            assert!(c_output.contains("struct typechecker__StructLayout {"));
            assert!(c_output.contains("struct typechecker__FunctionSignature {"));
            assert!(c_output.contains("struct typechecker__TypeEnvironment {"));
            assert!(c_output.contains("typechecker__env_pre_register_statement("));
        })
        .unwrap()
        .join()
        .unwrap();
}

#[test]
fn test_ast_serialization_helpers() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/ast_helpers_test_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = "
        import \"token.gst\" as token;
        import \"ast.gst\" as ast;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut strings: std.Vector[str, ctx] := std.VectorNew(ctx);
            strings.Push(\"hello\");
            strings.Push(\"world\");
            mut joined := ast.ast_join_strings(strings, \", \", ctx);
            os.LogStr(joined);

            mut fields: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);
            mut f: ast.FieldDef[ctx];
            f.name = \"my_field\";
            f.field_type.tag = 0;
            fields.Push(f);
            mut fields_str := ast.ast_join_fields(fields, 1, ctx);
            os.LogStr(fields_str);

            mut params: std.Vector[ast.Parameter[ctx], ctx] := std.VectorNew(ctx);
            mut param: ast.Parameter[ctx];
            param.name = \"my_param\";
            param.param_type.tag = 1;
            params.Push(param);
            mut params_str := ast.ast_join_params(params, 1, ctx);
            os.LogStr(params_str);
        }
    ";
    std::fs::write(&entry_path, entry_source).unwrap();

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
    let c_filename = format!("gust_e2e_ast_helpers_{:?}_{}.c", thread_id, process_id);
    let bin_filename = format!("gust_e2e_ast_helpers_{:?}_{}.bin", thread_id, process_id);

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_file(entry_path);

    assert_eq!(
        stdout_str.trim(),
        "hello, world\n  FieldDef: my_field : Int\n\n  Parameter: my_param : Byte"
    );
}

#[test]
fn test_self_hosted_domain_model_e2e() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/e2e_test_entry.gst");

    // Create compiler directory if it doesn't exist
    std::fs::create_dir_all("compiler").unwrap();

    // Programmatically fix errors.gst if it exists to be generic over ctx
    let errors_path = std::path::Path::new("compiler/errors.gst");
    if errors_path.exists() {
        if let Ok(content) = std::fs::read_to_string(&errors_path) {
            let mut updated = content;
            if updated.contains("type CompilerError struct") {
                updated = updated.replace(
                    "type CompilerError struct",
                    "type CompilerError[ctx] struct",
                );
            } else if updated.contains("type CompilerError  struct") {
                updated = updated.replace(
                    "type CompilerError  struct",
                    "type CompilerError[ctx] struct",
                );
            }
            if updated.contains("Index[CompilerError, ctx]") {
                updated = updated.replace(
                    "Index[CompilerError, ctx]",
                    "Index[CompilerError[ctx], ctx]",
                );
            }
            let _ = std::fs::write(&errors_path, updated);
        }
    }

    // Write a dummy entry file that imports token.gst, ast.gst, and errors.gst
    let entry_source = "
        import \"token.gst\" as token;
        import \"ast.gst\" as ast;
        import \"errors.gst\" as errs;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            
            mut p: ast.Program[ctx];
            p.statements = os.ArenaAlloc(ctx);
            
            mut s: ast.Statement[ctx];
            s.tag = 13;
            s.Expression.expr = os.ArenaAlloc(ctx);
            s.Expression.span.start.line = 1;
            s.Expression.span.start.column = 5;
            
            mut e: ast.Expression[ctx];
            e.tag = 1;
            e.Integer.val = 100;
            
            mut error_ptr: Index[errs.CompilerError[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx[error_ptr].kind.tag = 2;
            ctx[error_ptr].message = \"Type mismatch!\";
            ctx[error_ptr].span = s.Expression.span;
            
            mut res: errs.Result[Index[ast.Expression[ctx], ctx], ctx];
            res.tag = 1;
            res.Err.error = error_ptr;
            
            os.LogInt(ctx[res.Err.error].kind.tag);
            os.LogStr(ctx[res.Err.error].message);
        }
    ";
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

    let _program = gust_lexer::ast::Program {
        statements: Vec::new(), // Pass layout through modular mapping, not global unified statements
        span: gust_lexer::token::Span::dummy(),
    };

    let codegen = Codegen::new(
        checker.variable_types,
        checker.struct_registry,
        checker.function_registry,
        checker.enum_registry,
        checker.resolved_names,
        checker.resolved_types,
    );
    let c_output = codegen.generate(&modules_for_codegen);

    // Verify transpiled C contents for the entire multi-module compiler domain model
    assert!(c_output.contains("struct ast__Program"));
    assert!(c_output.contains("struct errors__CompilerError"));
    assert!(c_output.contains("struct errors__Result_Index_ast__Expression"));

    // Invoke GCC/Clang to compile the output and run it as an E2E test!
    let temp_dir = std::env::temp_dir();
    let thread_id = std::thread::current().id();
    let count = 42069;

    let c_filename = format!("gust_self_hosted_e2e_{:?}_{}.c", thread_id, count);
    let bin_filename = format!("gust_self_hosted_e2e_{:?}_{}.bin", thread_id, count);

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Failed to execute binary");

    // Clean up temporary files
    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_file(entry_path);

    assert!(run_output.status.success());
    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");
    assert_eq!(stdout_str.trim(), "2\nType mismatch!");
}

#[test]
fn test_self_hosted_program_serialization_e2e() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/serialization_e2e_entry.gst");

    // Create compiler directory if it doesn't exist
    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = r#"
        import "token.gst" as token;
        import "lexer.gst" as lexer;
        import "parser.gst" as parser;
        import "ast.gst" as ast;

        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut source := "import 'std' as standard;\ntype MyStruct struct {\n    val: int\n}\nfunc add(x: int) int {\n    return x + 1;\n}\nfunc main() {\n    mut x := 42;\n    while x < 50 {\n        x = x + 1;\n    }\n}";

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
    let count = 77777;

    let c_filename = format!("gust_serialization_e2e_{:?}_{}.c", thread_id, count);
    let bin_filename = format!("gust_serialization_e2e_{:?}_{}.bin", thread_id, count);

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Failed to execute binary");

    // Clean up temporary files
    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_file(entry_path);

    assert!(run_output.status.success());
    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    let expected = r#"Program:
  Import: std as standard
  StructDecl: MyStruct <>
    FieldDef: val : Int
  FunctionDecl: add -> Int
    Parameter: x : Int
    BlockStatement:
      Return:
        Binary: +
          Identifier: x
          Integer: 1
  FunctionDecl: main -> Void
    BlockStatement:
      VarDecl: x (mut=true) : <inferred>
        Integer: 42
      While:
        Binary: <
          Identifier: x
          Integer: 50
        BlockStatement:
          Assignment:
            Identifier: x
            Binary: +
              Identifier: x
              Integer: 1"#;

    assert_eq!(stdout_str.trim(), expected.trim());
}

#[test]
fn test_generational_arena_template_typechecking() {
    let source = "
        type Node struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut arena: std.GenerationalArena[Node, ctx];
            arena.current_ctx[arena.survivor].val = 42;
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_generational_arena_deep_copy_codegen() {
    let source = "
        type Node struct {
            val: int,
            next: Index[Node, ctx]
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut arena: std.GenerationalArena[Node, ctx];
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
    let check_res = checker.check_program(&program);
    assert!(
        check_res.is_ok(),
        "Typechecker error: {:?}",
        check_res.err()
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
    let c_output = codegen.generate(&modules_for_codegen);

    // Verify correct recursive clone generation
    assert!(c_output.contains(
        "int std_GenerationalArena_Clone_Node(os_Arena* dest, os_Arena* src, int src_idx);"
    ));
    assert!(c_output.contains(
        "int std_GenerationalArena_Clone_Node(os_Arena* dest, os_Arena* src, int src_idx) {"
    ));
    assert!(
        c_output.contains(
            "dest_ptr->next = std_GenerationalArena_Clone_Node(dest, src, src_ptr->next);"
        )
    );
}

#[test]
fn test_generational_arena_method_calls() {
    let source = "
        type Node struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut arena: std.GenerationalArena[Node, ctx];
            arena.Step();
            arena.Swap();
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
    let check_res = checker.check_program(&program);
    assert!(
        check_res.is_ok(),
        "Typechecker error: {:?}",
        check_res.err()
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
    let c_output = codegen.generate(&modules_for_codegen);

    // Verify transpiled C of the generational arenaStep/Swap
    assert!(c_output.contains("std_GenerationalArena_Step_Node(&arena);"));
}

#[test]
fn test_typecheck_logical_operators_invalid() {
    let source = "
        type Node struct { val: int }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut n: Node;
            mut ptr := &n;
            
            if n && ptr {
                os.LogInt(1);
            }
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TypeMismatch);
    assert!(err.message.contains("Left operand of logical"));
}

#[test]
fn test_fiber_scratchpad_escape_across_yield_boundary() {
    let source = "
        type Packet[ctx] struct {
            data: str
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            
            mut p: Packet[ctx];
            p.data = std.Format(\"Item %d\", 1);
            
            std.Yield();
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::BrandLifetimeViolation);
    assert!(
        err.message
            .contains("Cannot assign scratchpad-allocated view")
    );
}

#[test]
fn test_arena_validate_type_checking_valid() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            os.ArenaValidate(ctx);
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_arena_validate_type_checking_invalid() {
    let source = "
        func main() {
            mut x := 42;
            os.ArenaValidate(x);
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TypeMismatch);
}

#[test]
fn test_codegen_thread_local_redirection() {
    std::thread::Builder::new()
        .stack_size(104857600) // 100 MB
        .spawn(|| {
            gust_lexer::init_logging();
            let resolver = gust_lexer::resolver::ModuleResolver::new();
            let fs_impl = gust_lexer::resolver::RealFileSystem;
            let entry_path = std::path::Path::new("compiler/test_runner_entry.gst");

            let res = resolver.resolve(&entry_path, &fs_impl).unwrap();
            let (order, mut modules) = res;

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
                    checker.check_module(&module.program, &prefix).unwrap();
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
            let c_filename = format!("gust_e2e_codegen_tracing_{:?}_{}.c", thread_id, process_id);
            let bin_filename = format!(
                "gust_e2e_codegen_tracing_{:?}_{}.bin",
                thread_id, process_id
            );

            let c_path = temp_dir.join(&c_filename);
            let bin_path = temp_dir.join(&bin_filename);

            std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

            common::compile_c_program(&c_path, &bin_path, &c_output);

            let run_output = std::process::Command::new(&bin_path)
                .arg("compiler/test_scratch_storage_violation.gst")
                .output()
                .expect("Execution failed");

            let _stdout_str = String::from_utf8_lossy(&run_output.stdout).to_string();

            let _ = std::fs::remove_file(&c_path);
            let _ = std::fs::remove_file(&bin_path);
        })
        .unwrap()
        .join()
        .unwrap();
}

#[test]
fn test_match_pattern_destructuring_compile_pass() {
    let source = "
        type MyEnum enum {
            VariantA { val: int },
            VariantB { x: int, y: int }
        }
        func process(e: MyEnum) int {
            match e {                VariantA { val } => {
                    return val;
                }
                VariantB { x, y } => {
                    return x + y;
                }
            }
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_match_pattern_destructuring_field_not_found() {
    let source = "
        type MyEnum enum {
            VariantA { val: int },
            VariantB
        }
        func process(e: MyEnum) int {
            match e {
                VariantA { nonexistent } => {
                    return 1;
                }
                VariantB => {
                    return 0;
                }
            }
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::FieldNotFound);
    assert!(
        err.message
            .contains("Field 'nonexistent' not found on variant 'VariantA'")
    );
}

#[test]
fn test_match_pattern_destructuring_origin_invalidated() {
    let source = "
        type MyEnum enum {
            VariantA { val: str },
            VariantB
        }
        func main() {
            mut e: MyEnum;
            e.tag = 0;
            e.VariantA.val = \"hello\";
            
            match e {
                VariantA { val } => {
                    mut moved_e := move e;
                    os.LogStr(val); // Error: backing origin 'e' is invalidated!
                }
                VariantB => {}
            }
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert!(
        err.kind == TypeErrorKind::VariableOriginInvalidated
            || err.kind == TypeErrorKind::UseOfMovedVariable
    );
}

#[test]
fn test_match_pattern_destructuring_codegen() {
    let source = "
        type MyEnum enum {
            VariantA { val: int },
            VariantB { x: int, y: int }
        }
        func process(e: MyEnum) int {
            match e {
                VariantA { val } => {
                    return val;
                }
                VariantB { x, y } => {
                    return x + y;
                }
            }
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
        checker.resolved_names,
        checker.resolved_types,
    );
    let modules_for_codegen = vec![(std::path::PathBuf::from("input.gst"), program)];
    let c_output = codegen.generate(&modules_for_codegen);

    // Verify correct local variables declaration and assignment
    assert!(c_output.contains("int val = e.VariantA.val;"));
    assert!(c_output.contains("int x = e.VariantB.x;"));
    assert!(c_output.contains("int y = e.VariantB.y;"));
}

#[test]
fn test_guard_typechecks_valid_hashmap_get() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
            guard val := map.Get(42) else {
                return;
            }
            mut double_val := val * 2;
            os.LogInt(double_val);
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_guard_non_diverging_else_rejected() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
            mut dummy := 0;
            guard val := map.Get(42) else {
                dummy = 100;
            }
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TypeMismatch);
    assert!(err.message.contains("must diverge"));
}

#[test]
fn test_guard_non_wrapper_rhs_rejected() {
    let source = "
        func main() {
            guard val := 42 else {
                return;
            }
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TypeMismatch);
    assert!(
        err.message
            .contains("must evaluate to a fallible wrapper type")
    );
}

#[test]
fn test_guard_escape_analysis_and_borrow_invalidation() {
    let source = "
        type Packet struct {
            val: int
        }
        func main() {
            mut payload := os.MockPayload();
            guard result := payload as &Packet else {
                return;
            }
            mut moved_payload := move payload;
            os.LogInt(result.val);
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::VariableOriginInvalidated);
    assert!(err.message.contains("backing origin"));
}

#[test]
fn test_os_dir_and_entry_layouts() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut d: os.Dir[ctx];
            mut entry: os.DirEntry[ctx];
            os.CloseDir(d);
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_os_directory_ffi_type_checking() {
    let source_valid = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut opt_dir := os.OpenDir(ctx, \"src\");
            if opt_dir.Ok {
                mut d := opt_dir.Val;
                mut opt_entry := os.ReadDir(ctx, d);
                if opt_entry.Ok {
                    mut is_dir := opt_entry.Val.is_dir;
                    mut name := opt_entry.Val.name;
                }
                os.CloseDir(d);
            }
        }
    ";
    assert!(check_program(source_valid).is_ok());

    let source_brand_mismatch = "
        func main() {
            mut ctx1 := os.Arena.New();
            defer ctx1.Free();
            mut ctx2 := os.Arena.New();
            defer ctx2.Free();
            mut opt_dir := os.OpenDir(ctx1, \"src\");
            if opt_dir.Ok {
                mut opt_entry := os.ReadDir(ctx2, opt_dir.Val);
            }
        }
    ";
    assert!(check_program(source_brand_mismatch).is_err());

    let source_arg_count = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut opt_dir := os.OpenDir(ctx, \"src\");
            if opt_dir.Ok {
                os.CloseDir(opt_dir.Val, 42);
            }
        }
    ";
    assert!(check_program(source_arg_count).is_err());
}

#[test]
fn test_directory_resource_safety_checks() {
    let source_use_after_ctx_move = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut opt_dir := os.OpenDir(ctx, \"src\");
            if opt_dir.Ok {
                mut d := opt_dir.Val;
                mut ctx2 := move ctx;
                os.CloseDir(d);
            }
        }
    ";
    let res1 = check_program(source_use_after_ctx_move);
    assert!(res1.is_err());
    let err1 = res1.unwrap_err();
    assert_eq!(err1.kind, TypeErrorKind::UseOfMovedVariable);

    let source_leak_directory = "
        func leak() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut opt_dir := os.OpenDir(ctx, \"src\");
            if opt_dir.Ok {
                mut d := opt_dir.Val;
            }
        }
        func main() {}
    ";
    let res2 = check_program(source_leak_directory);
    assert!(res2.is_err());
    let err2 = res2.unwrap_err();
    assert_eq!(err2.kind, TypeErrorKind::BrandLifetimeViolation);
    assert!(err2.message.contains("must be cleanly closed"));

    let source_move_open_directory = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut opt_dir := os.OpenDir(ctx, \"src\");
            if opt_dir.Ok {
                mut d := opt_dir.Val;
                mut d2 := move d;
                os.CloseDir(d2);
            }
        }
    ";
    let res3 = check_program(source_move_open_directory);
    assert!(res3.is_err());
    let err3 = res3.unwrap_err();
    assert_eq!(err3.kind, TypeErrorKind::BrandLifetimeViolation);
    assert!(err3.message.contains("cannot be moved while open"));
}

#[test]
fn test_directory_invalid_namespace_or_field_access() {
    let source_invalid_field = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut opt_dir := os.OpenDir(ctx, \"src\");
            if opt_dir.Ok {
                mut d := opt_dir.Val;
                mut err := d.handle_corrupted;
            }
        }
    ";
    let res1 = check_program(source_invalid_field);
    assert!(res1.is_err());
    let err1 = res1.unwrap_err();
    assert_eq!(err1.kind, TypeErrorKind::FieldNotFound);

    let source_invalid_func = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut opt_dir := os.OpenDir_Invalid(ctx, \"src\");
        }
    ";
    let res2 = check_program(source_invalid_func);
    assert!(res2.is_err());
    let err2 = res2.unwrap_err();
    assert_eq!(err2.kind, TypeErrorKind::UndefinedFunction);
}

#[test]
fn test_directory_ffi_codegen_verification() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut opt_dir := os.OpenDir(ctx, \"src\");
            if opt_dir.Ok {
                mut d := opt_dir.Val;
                mut opt_entry := os.ReadDir(ctx, d);
                if opt_entry.Ok {
                    os.LogStr(opt_entry.Val.name);
                }
                os.CloseDir(d);
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
    let check_res = checker.check_program(&program);
    assert!(
        check_res.is_ok(),
        "Typechecker error: {:?}",
        check_res.err()
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
    let c_output = codegen.generate(&modules_for_codegen);

    // Verify critical codegen outputs
    assert!(c_output.contains("struct LookupResult_os_Dir {"));
    assert!(c_output.contains("struct LookupResult_os_DirEntry {"));
    assert!(c_output.contains("os_OpenDir("));
    assert!(c_output.contains("os_ReadDir("));
    assert!(c_output.contains("os_CloseDir("));
}

#[test]
fn test_vector_stack_type_checking_valid() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut vec: std.Vector[int, ctx] := std.VectorNew(ctx);
            vec.Push(10);
            mut val: int := vec.Pop();
            vec.Push(20);
            mut ptr: *int := vec.Back();
            vec.Clear();
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_vector_back_mutability_accepted() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut vec: std.Vector[int, ctx] := std.VectorNew(ctx);
            vec.Push(10);
            unsafe {
                mut ptr: *int := vec.Back();
                *ptr = 20;
            }
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_vector_pop_linear_ownership_enforced() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut vec: std.Vector[*int, ctx] := std.VectorNew(ctx);
            
            unsafe {
                mut val := 10;
                vec.Push(&val);
                
                mut p1 := vec.Pop();
                mut p2 := move p1;
                
                mut err := *p1; // Error: p1 was moved and is linear
            }
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::UseOfMovedVariable);
}

#[test]
fn test_hashmap_extended_methods_type_checking() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
            map.Insert(1, 10);
            
            mut keys: std.Vector[int, ctx] := map.Keys(ctx);
            map.Remove(1);
            map.Clear();
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_hashmap_keys_brand_lifetime_violation() {
    let source_invalid_arg = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut map: HashMap[int, int, ctx] := os.HashMapNew(ctx);
            mut keys := map.Keys(42); 
        }
    ";
    let res = check_program(source_invalid_arg);
    assert!(res.is_err());
    assert_eq!(res.unwrap_err().kind, TypeErrorKind::TypeMismatch);

    let source_mismatched_assignment = "
        func main() {
            mut ctx1 := os.Arena.New();
            defer ctx1.Free();
            mut ctx2 := os.Arena.New();
            defer ctx2.Free();
            mut map: HashMap[int, int, ctx1] := os.HashMapNew(ctx1);
            mut keys: std.Vector[int, ctx2] := map.Keys(ctx1); 
        }
    ";
    let res2 = check_program(source_mismatched_assignment);
    assert!(res2.is_err());
    assert_eq!(res2.unwrap_err().kind, TypeErrorKind::TypeMismatch);
}

#[test]
fn test_compile_os_args_and_exit() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut args: std.Vector[str, ctx] := os.Args(ctx);
            os.Exit(1);
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_concurrency_template_registration_valid() {
    let source = "
        type MyStruct struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut m: std.Mutex[MyStruct, ctx];
            mut c: std.Channel[int, ctx];
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_concurrency_template_argument_mismatch() {
    let source = "
        func main() {
            mut m: std.Mutex[int];
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TemplateArgumentMismatch);
}

#[test]
fn test_mutex_lock_type_safety() {
    let source = "
        type MyStruct struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut m: std.Mutex[MyStruct, ctx] := std.MutexNew(ctx);
            unsafe {
                mut ptr := m.Lock();
                (*ptr).val = 42;
                m.Unlock();
            }
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_channel_mismatched_send() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut c: std.Channel[str, ctx] := std.ChannelNew(ctx);
            c.Send(42);
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TypeMismatch);
}

#[test]
fn test_spawn_invalid_function() {
    let source_non_existent = "
        func main() {
            std.Spawn(non_existent_func, 42);
        }
    ";
    let res1 = check_program(source_non_existent);
    assert!(res1.is_err());
    assert_eq!(res1.unwrap_err().kind, TypeErrorKind::UndefinedFunction);

    let source_multi_param = "
        func task(a: int, b: int) {
        }
        func main() {
            std.Spawn(task, 42);
        }
    ";
    let res2 = check_program(source_multi_param);
    assert!(res2.is_err());
    assert_eq!(res2.unwrap_err().kind, TypeErrorKind::ArgumentMismatch);
}

#[test]
fn test_arena_moved_through_channel_invalid() {
    let source = "
        type CustomNode[ctx] struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut n: Index[CustomNode, ctx] := os.ArenaAlloc(ctx);
            ctx[n].val = 42;

            mut chan: std.Channel[Arena, ctx] := std.ChannelNew(ctx);
            chan.Send(move ctx);

            ctx[n].val = 100;
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert!(
        err.kind == TypeErrorKind::UseOfMovedVariable
            || err.kind == TypeErrorKind::AllocatorMovedOrFreed
    );
}

#[test]
fn test_scratchpad_origin_propagation() {
    let source = "
        func main() {
            mut p := os.ScratchAlloc(10);
            mut view := p;
        }
    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    let mut checker = TypeChecker::new();
    assert!(
        checker.check_program(&program).is_ok(),
        "Typechecking failed: {:?}",
        checker.check_program(&program).err()
    );

    // Verify p and view are of type RawPointer(Byte)
    let p_type = checker.variable_types.get("p").cloned().unwrap();
    assert!(matches!(&p_type, Type::RawPointer(inner) if **inner == Type::Byte));

    // Verify p and view are of type RawPointer(Byte)
    let view_type = checker.variable_types.get("view").cloned().unwrap();
    assert!(matches!(&view_type, Type::RawPointer(inner) if **inner == Type::Byte));

    // Verify origin propagation
    let view_origins = checker.all_variable_origins.get("view").cloned().unwrap();
    assert!(view_origins.contains("scratch"));
}

#[test]
fn test_scratch_assignment_to_branded_field_rejected() {
    let source = "
        type Node[ctx] struct {
            data: *byte
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut n: Index[Node, ctx] := os.ArenaAlloc(ctx);
            mut p := os.ScratchAlloc(10);
            
            ctx[n].data = p; // Error: Cannot assign scratchpad-allocated view to field of branded struct
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::BrandLifetimeViolation);
    assert!(
        err.message
            .contains("Cannot assign scratchpad-allocated view")
    );
}

#[test]
fn test_scratch_return_rejected() {
    let source = "
        func test_leak() *byte {
            mut p := os.ScratchAlloc(10);
            return p; // Error: Escape analysis violation
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
fn test_scratch_cloned_to_arena_accepted() {
    let source = "
        type Node[ctx] struct {
            data: Index[Any, ctx]
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut n: Index[Node, ctx] := os.ArenaAlloc(ctx);
            
            mut p: Index[Any, ctx] := os.ArenaAlloc(ctx);
            mut cloned := std.Clone(ctx, p);
            ctx[n].data = cloned;
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_multi_file_compilation_cycle() {
    use std::fs;
    let temp_dir = std::env::temp_dir().join("gust_test_cycle");
    fs::create_dir_all(&temp_dir).unwrap();

    let a_path = temp_dir.join("a.gst");
    let b_path = temp_dir.join("b.gst");

    fs::write(&a_path, "import \"b.gst\";").unwrap();
    fs::write(&b_path, "import \"a.gst\";").unwrap();

    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let res = resolver.resolve(&a_path, &fs_impl);

    assert!(res.is_err());
    let err = res.unwrap_err();
    assert!(err.message.contains("Cyclic dependency detected"));

    let _ = fs::remove_file(a_path);
    let _ = fs::remove_file(b_path);
    let _ = fs::remove_dir(temp_dir);
}

#[test]
fn test_namespaced_cross_module_typechecking_valid() {
    use std::fs;
    let temp_dir = std::env::temp_dir().join("gust_test_namespaced_valid");
    fs::create_dir_all(&temp_dir).unwrap();

    let main_path = temp_dir.join("main.gst");
    let lib_path = temp_dir.join("lib.gst");

    fs::write(
        &main_path,
        "import \"lib.gst\" as b; func main() { mut x: b.MyStruct; x.val = 42; }",
    )
    .unwrap();
    fs::write(&lib_path, "type MyStruct struct { val: int }").unwrap();

    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let res = resolver.resolve(&main_path, &fs_impl);
    assert!(res.is_ok());

    let (order, modules) = res.unwrap();
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
                "Failed on {:?}: {:?}",
                path,
                check_res.err()
            );
        }
    }

    let _ = fs::remove_file(main_path);
    let _ = fs::remove_file(lib_path);
    let _ = fs::remove_dir(temp_dir);
}

#[test]
fn test_path_join_typechecker_valid() {
    let source = r#"
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut path: str := os.path_join("a", "b", ctx);
        }
    "#;
    assert!(check_program(source).is_ok());
}

#[test]
fn test_str_find_and_trim_typechecker_valid() {
    let source = r#"
        func main() {
            mut s := "  hello  ";
            mut trimmed := std.str_trim(s);
            mut idx := std.str_find(trimmed, "ll");
        }
    "#;
    assert!(check_program(source).is_ok());
}

#[test]
fn test_str_split_typechecker_valid() {
    let source = r#"
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut s := "a,b,c";
            mut parts: std.Vector[str, ctx] := std.str_split(s, ",", ctx);
        }
    "#;
    assert!(check_program(source).is_ok());
}

#[test]
fn test_str_split_brand_mismatch_rejected() {
    let source = r#"
        func main() {
            mut ctx1 := os.Arena.New();
            defer ctx1.Free();
            mut ctx2 := os.Arena.New();
            defer ctx2.Free();
            mut s := "a,b,c";
            mut parts: std.Vector[str, ctx2] := std.str_split(s, ",", ctx1);
        }
    "#;
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TypeMismatch);
}

#[test]
fn test_path_join_arena_moved_rejected() {
    let source = r#"
        func main() {
            mut ctx := os.Arena.New();
            mut moved_ctx := move ctx;
            mut path := os.path_join("a", "b", ctx);
        }
    "#;
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::UseOfMovedVariable);
}

#[test]
fn test_format_typecheck_valid() {
    let source = "
        func main() {
            mut name := \"world\";
            mut s := std.Format(\"Hello %s, your id is %d\", name, 42);
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_format_non_literal_rejected() {
    let source = "
        func main() {
            mut template := \"Hello %d\";
            mut s := std.Format(template, 42); 
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    assert_eq!(res.unwrap_err().kind, TypeErrorKind::TypeMismatch);
}

#[test]
fn test_format_argument_count_mismatch() {
    let source = "
        func main() {
            mut s := std.Format(\"Hello %d %s\", 42); 
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    assert_eq!(res.unwrap_err().kind, TypeErrorKind::ArgumentMismatch);
}

#[test]
fn test_format_argument_type_mismatch() {
    let source = "
        func main() {
            mut s := std.Format(\"Hello %s\", 42); 
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    assert_eq!(res.unwrap_err().kind, TypeErrorKind::TypeMismatch);
}

#[test]
fn test_format_escape_via_return_rejected() {
    let source = "
        func leak() str {
            return std.Format(\"Hello %d\", 42); // Error: returning scratchpad-allocated view
        }
        func main() {}
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::BrandLifetimeViolation);
    assert!(err.message.contains("Returning scratchpad-allocated view"));
}

#[test]
fn test_format_assignment_to_branded_field_rejected() {
    let source = "
        type Node[ctx] struct {
            name: str
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut n: Index[Node, ctx] := os.ArenaAlloc(ctx);
            ctx[n].name = std.Format(\"Item %d\", 1); // Error: cannot assign scratchpad-allocated view to branded field
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::BrandLifetimeViolation);
    assert!(
        err.message
            .contains("Cannot assign scratchpad-allocated view")
    );
}

#[test]
fn test_format_clone_to_arena_accepted() {
    let source = "
        type Node[ctx] struct {
            name: str
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut n: Index[Node, ctx] := os.ArenaAlloc(ctx);
            
            // Cloning with std.Clone strips the volatile 'scratch' origin
            ctx[n].name = std.Clone(ctx, std.Format(\"Item %d\", 1)); 
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_namespaced_cross_module_typechecking_invalid_alias() {
    use std::fs;
    let temp_dir = std::env::temp_dir().join("gust_test_namespaced_invalid");
    fs::create_dir_all(&temp_dir).unwrap();

    let main_path = temp_dir.join("main.gst");
    let lib_path = temp_dir.join("lib.gst");

    fs::write(
        &main_path,
        "import \"lib.gst\" as b; func main() { mut x: wrong_alias.MyStruct; }",
    )
    .unwrap();
    fs::write(&lib_path, "type MyStruct struct { val: int }").unwrap();

    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let res = resolver.resolve(&main_path, &fs_impl);
    assert!(res.is_ok());

    let (order, modules) = res.unwrap();
    let mut checker = TypeChecker::new();

    let mut had_error = false;
    for path in &order {
        if let Some(module) = modules.get(path) {
            let stem = path.file_stem().unwrap().to_str().unwrap();
            let is_entry = path == order.last().unwrap();
            let prefix = if is_entry {
                "".to_string()
            } else {
                format!("{}__", stem)
            };
            if checker.check_module(&module.program, &prefix).is_err() {
                had_error = true;
                break;
            }
        }
    }
    assert!(had_error, "Expected typechecker to reject invalid alias");

    let _ = fs::remove_file(main_path);
    let _ = fs::remove_file(lib_path);
    let _ = fs::remove_dir(temp_dir);
}

#[test]
fn test_namespaced_nested_type_resolution() {
    use std::fs;
    let temp_dir = std::env::temp_dir().join("gust_test_namespaced_nested");
    fs::create_dir_all(&temp_dir).unwrap();

    let main_path = temp_dir.join("main.gst");
    let lib_path = temp_dir.join("lib.gst");

    fs::write(&main_path, "import \"lib.gst\" as b; func main() { mut ctx := os.Arena.New(); defer ctx.Free(); mut vec: std.Vector[b.MyStruct, ctx] := std.VectorNew(ctx); }").unwrap();
    fs::write(&lib_path, "type MyStruct struct { val: int }").unwrap();

    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let res = resolver.resolve(&main_path, &fs_impl);
    assert!(res.is_ok());

    let (order, modules) = res.unwrap();
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
                "Failed on {:?}: {:?}",
                path,
                check_res.err()
            );
        }
    }

    let _ = fs::remove_file(main_path);
    let _ = fs::remove_file(lib_path);
    let _ = fs::remove_dir(temp_dir);
}

#[test]
fn test_codegen_emits_line_directives() {
    let source = "
        func main() {
            mut x := 42;
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
        checker.resolved_names,
        checker.resolved_types,
    );
    let modules_for_codegen = vec![(std::path::PathBuf::from("my_test_module.gst"), program)];
    let c_output = codegen.generate(&modules_for_codegen);

    // Verify that the transpiled C contains expected #line preprocessor directives
    assert!(c_output.contains("#line 2 \"my_test_module.gst\""));
    assert!(c_output.contains("#line 3 \"my_test_module.gst\""));
}

#[test]
fn test_codegen_emits_multi_file_line_directives() {
    use std::fs;
    let temp_dir = std::env::temp_dir().join("gust_test_codegen_lines");
    fs::create_dir_all(&temp_dir).unwrap();

    let main_path = temp_dir.join("main.gst");
    let lib_path = temp_dir.join("lib.gst");

    // Fix: access helper() via the implicit "lib" namespace
    fs::write(
        &main_path,
        "import \"lib.gst\";\nfunc main() {\n    lib.helper();\n}",
    )
    .unwrap();
    fs::write(&lib_path, "\nfunc helper() {\n    mut y := 10;\n}").unwrap();

    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let res = resolver.resolve(&main_path, &fs_impl);
    assert!(res.is_ok());

    let (order, modules) = res.unwrap();
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
            assert!(check_res.is_ok());
        }
    }

    let mut modules_for_codegen = Vec::new();
    for path in &order {
        if let Some(module) = modules.get(path) {
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

    let main_escaped = main_path
        .to_string_lossy()
        .replace('\\', "\\\\")
        .replace('"', "\\\"");
    let lib_escaped = lib_path
        .to_string_lossy()
        .replace('\\', "\\\\")
        .replace('"', "\\\"");

    // Verify that #line preprocessor directives map back to distinct module paths
    assert!(c_output.contains(&format!("#line 2 \"{}\"", lib_escaped)));
    assert!(c_output.contains(&format!("#line 3 \"{}\"", lib_escaped)));
    assert!(c_output.contains(&format!("#line 2 \"{}\"", main_escaped)));
    assert!(c_output.contains(&format!("#line 3 \"{}\"", main_escaped)));

    let _ = fs::remove_file(main_path);
    let _ = fs::remove_file(lib_path);
    let _ = fs::remove_dir(temp_dir);
}

#[test]
fn test_nested_generic_type_mismatch_rejected() {
    let source = "
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut v1: std.Vector[std.Vector[int, ctx], ctx] := os.VectorNew(ctx);
            mut v2: std.Vector[std.Vector[bool, ctx], ctx] := os.VectorNew(ctx);
            v1 = v2;
        }
    ";
    let res = check_program(source);
    assert!(res.is_err());
    let err = res.unwrap_err();
    assert_eq!(err.kind, TypeErrorKind::TypeMismatch);
}

#[test]
fn test_recursive_branded_linked_list_propagation() {
    let source = "
        type ListNode[ctx] struct {
            val: int,
            next: Index[ListNode, ctx]
        }

        func process_list(ctx: &Arena, head: Index[ListNode, ctx]) int {
            mut curr := head;
            mut sum := 0;
            while curr != null {
                sum = sum + ctx[curr].val;
                curr = ctx[curr].next;
            }
            return sum;
        }

        func main() {
            mut c := os.Arena.New();
            defer c.Free();

            mut n1: Index[ListNode, c] := os.ArenaAlloc(c);
            c[n1].val = 10;

            mut n2: Index[ListNode, c] := os.ArenaAlloc(c);
            c[n2].val = 20;

            c[n1].next = n2;
            c[n2].next = null;

            mut total := process_list(c, n1);
            os.LogInt(total);
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_cross_module_template_namespacing_isolation() {
    use std::fs;
    let temp_dir = std::env::temp_dir().join("gust_test_namespaced_isolation");
    fs::create_dir_all(&temp_dir).unwrap();

    let main_path = temp_dir.join("main.gst");
    let lib_path = temp_dir.join("lib.gst");

    // lib.gst defines a non-generic Helper struct and a generic MyTemplate[T] having a field of type Helper
    fs::write(
        &lib_path,
        "type Helper struct { value: int }\ntype MyTemplate[T] struct { item: T, helper_field: Helper }"
    ).unwrap();

    // main.gst imports lib.gst as lib and instantiates lib.MyTemplate[int]
    fs::write(
        &main_path,
        "import \"lib.gst\" as lib;\nfunc main() {\n    mut ctx := os.Arena.New();\n    defer ctx.Free();\n    mut x: lib.MyTemplate[int];\n}"
    ).unwrap();

    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let res = resolver.resolve(&main_path, &fs_impl);
    assert!(res.is_ok());

    let (order, modules) = res.unwrap();
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
                "Failed on {:?}: {:?}",
                path,
                check_res.err()
            );
        }
    }

    // Assert that the monomorphized MyTemplate struct was registered under lib__MyTemplate_int
    assert!(checker.struct_registry.contains_key("lib__MyTemplate_int"));

    // Verify its fields: helper_field must point to lib__Helper!
    let layout = checker
        .struct_registry
        .get("lib__MyTemplate_int")
        .expect("Missing layout for MyTemplate");
    let helper_field_type = layout
        .fields
        .get("helper_field")
        .expect("Missing helper_field");
    assert_eq!(
        *helper_field_type,
        Type::Struct("lib__Helper".to_string(), None)
    );

    let _ = fs::remove_file(main_path);
    let _ = fs::remove_file(lib_path);
    let _ = fs::remove_dir(temp_dir);
}

#[test]
fn test_self_hosted_parser_scaffold() {
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/parser_test_comp_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = "
        import \"token.gst\" as token;
        import \"lexer.gst\" as lexer;
        import \"parser.gst\" as parser;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, \"mut a := 10;\");

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            parser.next_token(&p);

            mut is_mut := parser.cur_token_is(&p, 29); // Mut = 29
            mut is_ident := parser.peek_token_is(&p, 2); // Ident = 2

            guard tok := parser.expect_peek(&p, 2, ctx) else {
                return;
            }

            mut s := parser.merge_spans(p.cur_token.span, tok.span);
        }
    ";
    std::fs::write(&entry_path, entry_source).unwrap();

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, modules) = res.unwrap();
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
    assert!(c_output.contains("struct parser__Parser {"));
    assert!(c_output.contains("parser__next_token("));
    assert!(c_output.contains("parser__expect_peek("));

    let _ = std::fs::remove_file(entry_path);
}

#[test]
fn test_self_hosted_primitive_index_parsing() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/parser_primitive_index_test_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = "
        import \"token.gst\" as token;
        import \"lexer.gst\" as lexer;
        import \"parser.gst\" as parser;
        import \"ast.gst\" as ast;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, \"Index[str, ctx]\");

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            mut t_sig := parser.parse_type_signature(&p, ctx);
            
            os.LogInt(ctx[t_sig].tag); // Expected: 7 (Index)
            os.LogStr(ctx[t_sig].Index.struct_name); // Expected: str
            
            mut l2: lexer.Lexer[ctx];
            lexer.init_lexer(&l2, \"Index[int, ctx]\");
            
            mut p2: parser.Parser[ctx];
            parser.init_parser(&p2, &l2, ctx);
            
            mut t_sig2 := parser.parse_type_signature(&p2, ctx);
            os.LogStr(ctx[t_sig2].Index.struct_name); // Expected: int

            mut l3: lexer.Lexer[ctx];
            lexer.init_lexer(&l3, \"Index[std.Vector[int, ctx], ctx]\");
            
            mut p3: parser.Parser[ctx];
            parser.init_parser(&p3, &l3, ctx);
            
            mut t_sig3 := parser.parse_type_signature(&p3, ctx);
            os.LogStr(ctx[t_sig3].Index.struct_name); // Expected: std_Vector_int_ctx
        }
    ";
    std::fs::write(&entry_path, entry_source).unwrap();

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, modules) = res.unwrap();
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
                "Typechecking failed: {:?}",
                check_res.err()
            );
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
    let mut modules_for_codegen = Vec::new();
    for path in &order {
        if let Some(module) = modules.get(path) {
            modules_for_codegen.push((path.clone(), module.program.clone()));
        }
    }
    let c_output = codegen.generate(&modules_for_codegen);

    let temp_dir = std::env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let c_filename = format!("gust_e2e_prim_index_{:?}_{}.c", thread_id, process_id);
    let bin_filename = format!("gust_e2e_prim_index_{:?}_{}.bin", thread_id, process_id);

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_file(entry_path);

    assert_eq!(stdout_str.trim(), "7\nstr\nint\nstd_Vector_int_ctx");
}

#[test]
fn test_self_hosted_full_parsing() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/parser_full_test_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = r#"
        import "token.gst" as token;
        import "lexer.gst" as lexer;
        import "parser.gst" as parser;
        import "ast.gst" as ast;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            // 1. Parse a function declaration
            mut l1: lexer.Lexer[ctx];
            lexer.init_lexer(&l1, "func add(x: int, y: int) int { return x + y; }");
            mut p1: parser.Parser[ctx];
            parser.init_parser(&p1, &l1, ctx);
            mut stmt1 := parser.parse_statement(&p1, ctx);
            os.LogInt(ctx[stmt1].tag);
            os.LogStr(ctx[stmt1].FunctionDecl.name);

            // 2. Parse a match statement
            mut l2: lexer.Lexer[ctx];
            lexer.init_lexer(&l2, "match shape { Circle { radius } => { return 1; }, Point => { return 2; } }");
            mut p2: parser.Parser[ctx];
            parser.init_parser(&p2, &l2, ctx);
            mut stmt2 := parser.parse_statement(&p2, ctx);
            os.LogInt(ctx[stmt2].tag);

            // 3. Parse a defer statement
            mut l3: lexer.Lexer[ctx];
            lexer.init_lexer(&l3, "defer ctx.Free();");
            mut p3: parser.Parser[ctx];
            parser.init_parser(&p3, &l3, ctx);
            mut stmt3 := parser.parse_statement(&p3, ctx);
            os.LogInt(ctx[stmt3].tag);

            // 4. Parse an unsafe block
            mut l4: lexer.Lexer[ctx];
            lexer.init_lexer(&l4, "unsafe { return; }");
            mut p4: parser.Parser[ctx];
            parser.init_parser(&p4, &l4, ctx);
            mut stmt4 := parser.parse_statement(&p4, ctx);
            os.LogInt(ctx[stmt4].tag);
        }
    "#;
    std::fs::write(&entry_path, entry_source).unwrap();

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, modules) = res.unwrap();
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
    assert!(c_output.contains("parser__parse_function_decl("));
    assert!(c_output.contains("parser__parse_match_statement("));
    assert!(c_output.contains("parser__parse_defer_statement("));
    assert!(c_output.contains("parser__parse_unsafe_block("));

    let temp_dir = std::env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let c_filename = format!("gust_e2e_full_comp_{:?}_{}.c", thread_id, process_id);
    let bin_filename = format!("gust_e2e_full_comp_{:?}_{}.bin", thread_id, process_id);

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_file(entry_path);

    assert_eq!(stdout_str.trim(), "3\nadd\n8\n11\n10");
}

#[test]
fn test_self_hosted_type_parsing() {
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/parser_type_test_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = "
        import \"token.gst\" as token;
        import \"lexer.gst\" as lexer;
        import \"parser.gst\" as parser;
        import \"ast.gst\" as ast;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, \"type MyStruct[T] struct { x: int, y: bool }\");

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            mut stmt := parser.parse_statement(&p, ctx);
            os.LogInt(ctx[stmt].tag);
            os.LogStr(ctx[stmt].StructDecl.name);
            
            mut l2: lexer.Lexer[ctx];
            lexer.init_lexer(&l2, \"type MyEnum enum { Circle { r: int }, Point }\");
            
            mut p2: parser.Parser[ctx];
            parser.init_parser(&p2, &l2, ctx);
            
            mut stmt2 := parser.parse_statement(&p2, ctx);
            os.LogInt(ctx[stmt2].tag);
            os.LogStr(ctx[stmt2].EnumDecl.name);
        }
    ";
    std::fs::write(&entry_path, entry_source).unwrap();

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, modules) = res.unwrap();
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
    assert!(c_output.contains("parser__parse_struct_decl("));

    let temp_dir = std::env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let c_filename = format!("gust_e2e_types_comp_{:?}_{}.c", thread_id, process_id);
    let bin_filename = format!("gust_e2e_types_comp_{:?}_{}.bin", thread_id, process_id);

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_file(entry_path);

    assert_eq!(stdout_str.trim(), "1\nMyStruct\n2\nMyEnum");
}

#[test]
fn test_self_hosted_statement_parsing() {
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/parser_statement_test_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = "
        import \"token.gst\" as token;
        import \"lexer.gst\" as lexer;
        import \"parser.gst\" as parser;
        import \"ast.gst\" as ast;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, \"while 1 { mut x: int := 42; if x { x = 20; } else { x = 30; } guard mut y := 10 else { return; } }\");

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            mut stmt := parser.parse_statement(&p, ctx);
        }
    ";
    std::fs::write(&entry_path, entry_source).unwrap();

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, modules) = res.unwrap();
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
    assert!(c_output.contains("parser__parse_statement("));
    assert!(c_output.contains("parser__parse_var_decl("));
    assert!(c_output.contains("parser__parse_while_statement("));
    assert!(c_output.contains("parser__parse_if_statement("));
    assert!(c_output.contains("parser__parse_guard_statement("));

    let _ = std::fs::remove_file(entry_path);
}

#[test]
fn test_self_hosted_prefix_parsing() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/parser_prefix_test_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = r#"
        import "token.gst" as token;
        import "lexer.gst" as lexer;
        import "parser.gst" as parser;
        import "ast.gst" as ast;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, "*&move x");

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            mut expr := parser.parse_expression(&p, 1, ctx);
            
            os.LogInt(ctx[expr].tag);
            
            mut inner1 := ctx[expr].Dereference.expr;
            os.LogInt(ctx[inner1].tag);
            
            mut inner2 := ctx[inner1].AddressOf.expr;
            os.LogInt(ctx[inner2].tag);
            
            mut inner3 := ctx[inner2].Move.expr;
            os.LogInt(ctx[inner3].tag);
            os.LogStr(ctx[inner3].Identifier.name);
        }
    "#;
    std::fs::write(&entry_path, entry_source).unwrap();

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, modules) = res.unwrap();
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
    assert!(c_output.contains("parser__parse_expression("));

    let temp_dir = std::env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let c_filename = format!("gust_e2e_prefix_{:?}_{}.c", thread_id, process_id);
    let bin_filename = format!("gust_e2e_prefix_{:?}_{}.bin", thread_id, process_id);

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_file(entry_path);

    assert_eq!(stdout_str.trim(), "7\n6\n4\n0\nx");
}

#[test]
fn test_self_hosted_import_parsing() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/parser_import_test_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = r#"
        import "token.gst" as token;
        import "lexer.gst" as lexer;
        import "parser.gst" as parser;
        import "ast.gst" as ast;
        
        func test_valid() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, "import 'token.gst' as token;\nimport 'lexer.gst';\nmut x := 42;");

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            mut prog := parser.parse_program(&p, ctx);
            os.LogInt(len(p.errors)); // Expected: 0
            unsafe {
                    mut statements_ptr := &ctx[prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
                    os.LogInt((*statements_ptr).len); // Expected: 3
            }
        }

        func test_misplaced() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, "mut x := 42;\nimport 'token.gst';");

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            mut prog := parser.parse_program(&p, ctx);
            os.LogInt(len(p.errors)); // Expected: 1
        }

        func main() {
            test_valid();
            test_misplaced();
        }
    "#;
    std::fs::write(&entry_path, entry_source).unwrap();

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
        if let Some(module) = modules.get_mut(path) {
            modules_for_codegen.push((path.clone(), module.program.clone()));
        }
    }
    let c_output = codegen.generate(&modules_for_codegen);
    assert!(c_output.contains("parser__parse_program("));
    assert!(c_output.contains("parser__parse_import_statement("));

    let temp_dir = std::env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let c_filename = format!("gust_e2e_import_{:?}_{}.c", thread_id, process_id);
    let bin_filename = format!("gust_e2e_import_{:?}_{}.bin", thread_id, process_id);

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");
    let stderr_str = String::from_utf8_lossy(&run_output.stderr);

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_file(entry_path);

    if !run_output.status.success() {
        panic!(
            "Execution failed!\nSTDOUT:\n{}\nSTDERR:\n{}",
            stdout_str, stderr_str
        );
    }

    assert_eq!(stdout_str.trim(), "0\n3\n1");
}

#[test]
fn test_self_hosted_parser_recovery() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/parser_recovery_test_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = r#"
        import "token.gst" as token;
        import "lexer.gst" as lexer;
        import "parser.gst" as parser;
        import "ast.gst" as ast;
        
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, "type MyStruct struct { field: } func main() {}");

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            mut prog := parser.parse_program(&p, ctx);
            os.LogInt(len(p.errors)); // Expected: 1
            unsafe {
                mut statements_ptr := &ctx[prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
                os.LogInt((*statements_ptr).len); // Expected: 1
                if (*statements_ptr).len > 0 {
                    mut main_stmt := (*statements_ptr)[0];
                    os.LogInt(main_stmt.tag); // Expected: 3 (FunctionDecl)
                    os.LogStr(main_stmt.FunctionDecl.name); // Expected: main
                }
            }
        }
    "#;
    std::fs::write(&entry_path, entry_source).unwrap();

    let res = resolver.resolve(&entry_path, &fs_impl);
    assert!(res.is_ok(), "Module resolution failed: {:?}", res.err());

    let (order, modules) = res.unwrap();
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
    assert!(c_output.contains("parser__parse_program("));
    assert!(c_output.contains("parser__synchronize("));

    let temp_dir = std::env::temp_dir();
    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let c_filename = format!("gust_e2e_recovery_{:?}_{}.c", thread_id, process_id);
    let bin_filename = format!("gust_e2e_recovery_{:?}_{}.bin", thread_id, process_id);

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");
    let stderr_str = String::from_utf8_lossy(&run_output.stderr);

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_file(entry_path);

    if !run_output.status.success() {
        panic!(
            "Execution failed!\nSTDOUT:\n{}\nSTDERR:\n{}",
            stdout_str, stderr_str
        );
    }

    assert_eq!(stdout_str.trim(), "1\n1\n3\nmain");
}

#[test]
fn test_self_hosted_type_serialization() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/type_serialization_test_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = "
            import 'token.gst' as token;
            import 'ast.gst' as ast;
            func main() {
                mut ctx := os.Arena.New();
                defer ctx.Free();

                // 1. Primitive Type Int
                mut t_int: ast.Type[ctx];
                t_int.tag = 0;
                os.LogStr(ast.serialize_type(t_int, ctx));

                // 2. Struct Type
                mut t_struct: ast.Type[ctx];
                t_struct.tag = 8;
                t_struct.Struct.struct_name = 'MyNode';
                t_struct.Struct.brand = empty[Index[str, ctx]];
                os.LogStr(ast.serialize_type(t_struct, ctx));

                // 3. Branded Struct Type
                mut t_branded: ast.Type[ctx];
                t_branded.tag = 8;
                t_branded.Struct.struct_name = 'MyNode';
                mut brand_idx: Index[str, ctx] := os.ArenaAlloc(ctx);
                t_branded.Struct.brand = brand_idx;
                unsafe {
                    mut brand_ptr := &ctx[t_branded.Struct.brand] as *str;
                    *brand_ptr = 'connCtx';
                }
                os.LogStr(ast.serialize_type(t_branded, ctx));

                // 4. Raw Pointer Type
                mut t_ptr: ast.Type[ctx];
                t_ptr.tag = 9;
                mut inner_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
                t_ptr.RawPointer.inner = inner_idx;
                ctx[t_ptr.RawPointer.inner].tag = 0;
                os.LogStr(ast.serialize_type(t_ptr, ctx));

                // 5. Generic Type
                mut t_gen: ast.Type[ctx];
                t_gen.tag = 10;
                t_gen.Generic.name = 'std.Vector';
                
                mut args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);

                mut arg1: ast.Type[ctx];
                arg1.tag = 0;
                args.Push(arg1);

                mut arg2: ast.Type[ctx];
                arg2.tag = 8;
                arg2.Struct.struct_name = 'ctx';
                arg2.Struct.brand = empty[Index[str, ctx]];
                args.Push(arg2);

                mut args_idx: Index[std.Vector[ast.Type[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
                unsafe {
                    mut args_ptr := &ctx[args_idx] as *std.Vector[ast.Type[ctx], ctx];
                    *args_ptr = args;
                }
                t_gen.Generic.args = args_idx;

                os.LogStr(ast.serialize_type(t_gen, ctx));
            }
        ";
    std::fs::write(&entry_path, entry_source).unwrap();

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
        "gust_e2e_type_serialization_{:?}_{}.c",
        thread_id, process_id
    );
    let bin_filename = format!(
        "gust_e2e_type_serialization_{:?}_{}.bin",
        thread_id, process_id
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_file(entry_path);

    assert_eq!(
        stdout_str.trim(),
        "Int\nStruct(\"MyNode\", None)\nStruct(\"MyNode\", Some(\"connCtx\"))\nRawPointer(Int)\nGeneric(\"std.Vector\", [Int, Struct(\"ctx\", None)])"
    );
}

#[test]
fn test_self_hosted_expression_serialization() {
    gust_lexer::init_logging();
    let resolver = gust_lexer::resolver::ModuleResolver::new();
    let fs_impl = gust_lexer::resolver::RealFileSystem;
    let entry_path = std::path::Path::new("compiler/expression_serialization_test_entry.gst");

    std::fs::create_dir_all("compiler").unwrap();

    let entry_source = "
            import 'token.gst' as token;
            import 'lexer.gst' as lexer;
            import 'parser.gst' as parser;
            import 'ast.gst' as ast;
            func main() {
                mut ctx := os.Arena.New();
                defer ctx.Free();

                // 1. Identifier
                mut l1: lexer.Lexer[ctx];
                lexer.init_lexer(&l1, 'my_var');
                mut p1: parser.Parser[ctx];
                parser.init_parser(&p1, &l1, ctx);
                mut expr1 := parser.parse_expression(&p1, 1, ctx);
                os.LogStr(ast.serialize_expression(expr1, 0, ctx));

                // 2. Binary and Integer
                mut l2: lexer.Lexer[ctx];
                lexer.init_lexer(&l2, '42 + 10');
                mut p2: parser.Parser[ctx];
                parser.init_parser(&p2, &l2, ctx);
                mut expr2 := parser.parse_expression(&p2, 1, ctx);
                os.LogStr(ast.serialize_expression(expr2, 0, ctx));

                // 3. String & Bool
                mut l3: lexer.Lexer[ctx];
                lexer.init_lexer(&l3, '\\\"hello\\\" == true');
                mut p3: parser.Parser[ctx];
                parser.init_parser(&p3, &l3, ctx);
                mut expr3 := parser.parse_expression(&p3, 1, ctx);
                os.LogStr(ast.serialize_expression(expr3, 0, ctx));

                // 4. Selector & IndexAccess
                mut l4: lexer.Lexer[ctx];
                lexer.init_lexer(&l4, 'ctx[n].val');
                mut p4: parser.Parser[ctx];
                parser.init_parser(&p4, &l4, ctx);
                mut expr4 := parser.parse_expression(&p4, 1, ctx);
                os.LogStr(ast.serialize_expression(expr4, 0, ctx));

                // 5. Call & Cast & Empty
                mut l5: lexer.Lexer[ctx];
                lexer.init_lexer(&l5, 'my_func(empty[int] as *int)');
                mut p5: parser.Parser[ctx];
                parser.init_parser(&p5, &l5, ctx);
                mut expr5 := parser.parse_expression(&p5, 1, ctx);
                os.LogStr(ast.serialize_expression(expr5, 0, ctx));
            }
        ";
    std::fs::write(&entry_path, entry_source).unwrap();

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
        "gust_e2e_expression_serialization_{:?}_{}.c",
        thread_id, process_id
    );
    let bin_filename = format!(
        "gust_e2e_expression_serialization_{:?}_{}.bin",
        thread_id, process_id
    );

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_output);

    let run_output = std::process::Command::new(&bin_path)
        .output()
        .expect("Execution failed");

    let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

    let _ = std::fs::remove_file(&c_path);
    let _ = std::fs::remove_file(&bin_path);
    let _ = std::fs::remove_file(entry_path);

    assert_eq!(
        stdout_str.trim(),
        "Identifier: my_var\n\nBinary: +\n  Integer: 42\n  Integer: 10\n\nBinary: ==\n  String: \"hello\"\n  Bool: true\n\nSelector: val\n  IndexAccess:\n    Identifier: ctx\n    Identifier: n\n\nCall:\n  Identifier: my_func\n  AsCast: RawPointer(Int) (ref=false)\n    Empty: Int"
    );
}

#[test]
fn test_namespaced_fallback_type_matching() {
    let source = "
        type MyStruct struct {
            val: int
        }
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut vec: std.Vector[MyStruct, ctx] := std.VectorNew(ctx);
        }
    ";
    assert!(check_program(source).is_ok());
}

#[test]
fn test_namespaced_generic_type_signature_mismatch_reproduction() {
    gust_lexer::init_logging();
    use std::fs;
    let temp_dir = env::temp_dir().join("gust_test_namespaced_reproduction");
    fs::create_dir_all(&temp_dir).unwrap();

    let main_path = temp_dir.join("main.gst");
    let lib_path = temp_dir.join("lib.gst");

    let lib_source = "
        type MyGeneric[ctx] enum {
            Variant { val: int }
        }
        func process(ctx: &Arena) {
            unsafe {
                mut args_vec := empty[*int] as *std.Vector[MyGeneric[ctx], ctx];
            }
        }
    ";

    let main_source = "
        import \"lib.gst\" as lib;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            lib.process(ctx);
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
            if let Err(err) = checker.check_module(&module.program, &prefix) {
                let diagnostic = gust_lexer::typechecker::format_diagnostic(&module.source, &err);
                panic!("Typechecking failed on {:?}:\n{}", path, diagnostic);
            }
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

    let thread_id = std::thread::current().id();
    let process_id = std::process::id();
    let c_filename = format!("gust_e2e_repro_{:?}_{}.c", thread_id, process_id);
    let bin_filename = format!("gust_e2e_repro_{:?}_{}.bin", thread_id, process_id);

    let c_path = temp_dir.join(&c_filename);
    let bin_path = temp_dir.join(&bin_filename);

    fs::write(&c_path, &c_code).expect("Failed to write temporary C file");

    common::compile_c_program(&c_path, &bin_path, &c_code);

    let _ = fs::remove_file(&c_path);
    let _ = fs::remove_file(&bin_path);
    let _ = fs::remove_file(&main_path);
    let _ = fs::remove_file(&lib_path);
    let _ = fs::remove_dir(temp_dir);
}

#[test]
fn test_self_hosted_typechecker_monomorphize_argument_mismatch() {
    std::thread::Builder::new()
        .stack_size(104857600) // 100 MB
        .spawn(|| {
            gust_lexer::init_logging();
            let resolver = gust_lexer::resolver::ModuleResolver::new();
            let fs_impl = gust_lexer::resolver::RealFileSystem;
            let entry_path = std::path::Path::new("compiler/typechecker_mismatch_test_entry.gst");

            std::fs::create_dir_all("compiler").unwrap();

            let entry_source = r#"
                import "token.gst" as token;
                import "ast.gst" as ast;
                import "typechecker.gst" as typechecker;
                func main() {
                    mut ctx := os.Arena.New();
                    defer ctx.Free();
                    os.SetThreadScratch(ctx);

                    mut env := typechecker.env_new(ctx);

                    // Trigger argument mismatch: std.Vector expects 2 arguments but we provide 1
                    mut vec_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
                    vec_args.Push(typechecker.make_type_int());

                    mut res := typechecker.monomorphize(&env, "std.Vector", vec_args, ctx);
                    if res.tag == 1 { // Err
                        os.LogStr("Argument mismatch correctly detected!");
                        unsafe {
                            os.LogStr(ctx[res.Err.error].message);
                        }
                    } else {
                        os.LogStr("Failed to detect argument mismatch!");
                    }
                }
            "#;
            std::fs::write(&entry_path, entry_source).unwrap();

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
            let c_filename = format!("gust_e2e_mismatch_{:?}_{}.c", thread_id, process_id);
            let bin_filename = format!("gust_e2e_mismatch_{:?}_{}.bin", thread_id, process_id);

            let c_path = temp_dir.join(&c_filename);
            let bin_path = temp_dir.join(&bin_filename);

            std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

            common::compile_c_program(&c_path, &bin_path, &c_output);

            let run_output = std::process::Command::new(&bin_path)
                .output()
                .expect("Execution failed");

            let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

            let _ = std::fs::remove_file(&c_path);
            let _ = std::fs::remove_file(&bin_path);
            let _ = std::fs::remove_file(entry_path);

            let filtered_stdout: String = stdout_str
                .lines()
                .filter(|line| {
                    !line.starts_with("🗄️") && !line.starts_with("🔄") && !line.starts_with("👁️")
                })
                .collect::<Vec<_>>()
                .join("\n");
            assert_eq!(
                filtered_stdout.trim(),
                "Argument mismatch correctly detected!\nSemantic Error: Template 'std.Vector' expects 2 generic arguments but got 1"
            );
        })
        .unwrap()
        .join()
        .unwrap();
}





#[test]
fn test_bootstrapped_compiler_helper_initialization() {
    let compiler_path = common::get_compiled_compiler();
    assert!(compiler_path.exists(), "Compiled self-hosted compiler does not exist");
    assert!(compiler_path.is_file(), "Compiled self-hosted compiler path is not a file");

    let output = std::process::Command::new(compiler_path)
        .output()
        .expect("Failed to execute compiled self-hosted compiler");

    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(
        stdout.contains("Usage: test_runner_entry"),
        "Self-hosted compiler did not print usage information: {}",
        stdout
    );
}








#[test]
fn test_adt_metadata_and_tag_enum_generation() {
    let source = "\n        type Status enum {\n            Pending,\n            Active,\n            Failed\n        }\n        func main() {\n            mut s: Status;\n        }\n    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    assert!(
        parser.errors.is_empty(),
        "Parser errors: {:?}",
        parser.errors
    );

    let mut checker = TypeChecker::new();
    let check_res = checker.check_program(&program);
    assert!(
        check_res.is_ok(),
        "Typechecker error: {:?}",
        check_res.err()
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
    let c_output = codegen.generate(&modules_for_codegen);

    // Verify the generated C contains the typedef enum for variant tags
    assert!(
        c_output.contains("Status_Tag__Pending = 0,"),
        "Missing Pending tag"
    );
    assert!(
        c_output.contains("Status_Tag__Active = 1,"),
        "Missing Active tag"
    );
    assert!(
        c_output.contains("Status_Tag__Failed = 2,"),
        "Missing Failed tag"
    );
    assert!(
        c_output.contains("} Status_Tag;"),
        "Missing Status_Tag typedef"
    );
}

#[test]
fn test_adt_payload_struct_and_union_emission() {
    let source = "\n        type Status enum {\n            Pending,\n            Active,\n            Failed\n        }\n        func main() {\n            mut s: Status;\n        }\n    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    assert!(
        parser.errors.is_empty(),
        "Parser errors: {:?}",
        parser.errors
    );

    let mut checker = TypeChecker::new();
    let check_res = checker.check_program(&program);
    assert!(
        check_res.is_ok(),
        "Typechecker error: {:?}",
        check_res.err()
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
    let c_output = codegen.generate(&modules_for_codegen);

    // Verify payload structs and union are emitted
    assert!(
        c_output.contains("struct Status_Pending {"),
        "Missing Status_Pending struct"
    );
    assert!(
        c_output.contains("struct Status_Active {"),
        "Missing Status_Active struct"
    );
    assert!(
        c_output.contains("struct Status_Failed {"),
        "Missing Status_Failed struct"
    );
    assert!(
        c_output.contains("struct Status {"),
        "Missing Status parent struct"
    );
    assert!(c_output.contains("union {"), "Missing anonymous union");

    // Verify correct topological order (variants defined before the parent union container)
    let idx_pending = c_output
        .find("struct Status_Pending {")
        .expect("Status_Pending index");
    let idx_active = c_output
        .find("struct Status_Active {")
        .expect("Status_Active index");
    let idx_failed = c_output
        .find("struct Status_Failed {")
        .expect("Status_Failed index");
    let idx_parent = c_output
        .find("struct Status {")
        .expect("Status parent index");

    assert!(
        idx_pending < idx_parent,
        "Status_Pending must be defined before Status"
    );
    assert!(
        idx_active < idx_parent,
        "Status_Active must be defined before Status"
    );
    assert!(
        idx_failed < idx_parent,
        "Status_Failed must be defined before Status"
    );
}

#[test]
fn test_adt_variant_constructor_and_initializer_logic() {
    let source = "\n        type Status enum {\n            Pending,\n            Active { since: int },\n            Failed\n        }\n        func main() {\n            mut s: Status;\n            s.tag = 1;\n            s.Active.since = 0;\n        }\n    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    assert!(
        parser.errors.is_empty(),
        "Parser errors: {:?}",
        parser.errors
    );

    let mut checker = TypeChecker::new();
    let check_res = checker.check_program(&program);
    assert!(
        check_res.is_ok(),
        "Typechecker error: {:?}",
        check_res.err()
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
    let c_output = codegen.generate(&modules_for_codegen);

    // Verify correct local variables initialization
    assert!(
        c_output.contains("Status s = ((Status){ .tag = 0 });"),
        "Missing status initialization"
    );
    // Verify assignments are generated correctly
    assert!(c_output.contains("s.tag = 1;"), "Missing tag assignment");
    assert!(
        c_output.contains("s.Active.since = 0;"),
        "Missing union field assignment"
    );
}

#[test]
fn test_refined_match_statement_codegen() {
    let source = "\n        type Status enum {\n            Pending,\n            Active,\n            Failed\n        }\n        func process(s: Status) int {\n            match s {\n                Pending => {\n                    return 1;\n                }\n                Active => {\n                    return 2;\n                }\n                Failed => {\n                    return 3;\n                }\n            }\n        }\n    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    assert!(
        parser.errors.is_empty(),
        "Parser errors: {:?}",
        parser.errors
    );

    let mut checker = TypeChecker::new();
    let check_res = checker.check_program(&program);
    assert!(
        check_res.is_ok(),
        "Typechecker error: {:?}",
        check_res.err()
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
    let c_output = codegen.generate(&modules_for_codegen);

    // Verify the match statement is translated to C switch with named tag constants
    assert!(
        c_output.contains("switch (s.tag) {"),
        "Missing switch on s.tag"
    );
    assert!(
        c_output.contains("case Status_Tag__Pending:"),
        "Missing case for Pending"
    );
    assert!(
        c_output.contains("case Status_Tag__Active:"),
        "Missing case for Active"
    );
    assert!(
        c_output.contains("case Status_Tag__Failed:"),
        "Missing case for Failed"
    );
}

#[test]
fn test_e2e_self_hosted_codegen_tracing() {
    std::thread::Builder::new()
        .stack_size(104857600) // 100 MB
        .spawn(|| {
            gust_lexer::init_logging();
            let resolver = gust_lexer::resolver::ModuleResolver::new();
            let fs_impl = gust_lexer::resolver::RealFileSystem;
            let entry_path = std::path::Path::new("compiler/test_runner_entry.gst");

            let res = resolver.resolve(&entry_path, &fs_impl).unwrap();
            let (order, mut modules) = res;

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
                    if let Err(e) = checker.check_module(&module.program, &prefix) {
                        let diag = gust_lexer::typechecker::format_diagnostic(&module.source, &e);
                        panic!("Typechecking failed on {:?}:\n{}", path, diag);
                    }
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
            let c_filename = format!("gust_e2e_codegen_tracing_{:?}_{}.c", thread_id, process_id);
            let bin_filename = format!(
                "gust_e2e_codegen_tracing_{:?}_{}.bin",
                thread_id, process_id
            );

            let c_path = temp_dir.join(&c_filename);
            let bin_path = temp_dir.join(&bin_filename);

            std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

            // Use the shared compilation helper with the raw compiler output
            common::compile_c_program(&c_path, &bin_path, &c_output);

            // Execute the compiled binary
            let run_output = std::process::Command::new(&bin_path)
                .arg("compiler/test_scratch_storage_violation.gst")
                .output()
                .expect("Execution failed");

            let _ = std::fs::remove_file(&c_path);
            let _ = std::fs::remove_file(&bin_path);

            if run_output.status.success() {
                let stderr_str = String::from_utf8_lossy(&run_output.stderr);
                let stdout_str = String::from_utf8_lossy(&run_output.stdout);
                panic!( 
                    "Execution succeeded but was expected to fail! STDOUT:\n{}\nSTDERR:\n{}",
                    stdout_str, stderr_str
                );
            }

            let stdout_str = String::from_utf8(run_output.stdout).expect("Invalid UTF-8");

            // Assert the presence of all expected structured tracing emojis with expected payloads!
            assert!(stdout_str.contains("🗄 scope_new: spawned root scope") || stdout_str.contains("scope_new"));
            assert!(stdout_str.contains("env_register_function: registered function 'main' with 0 parameters"));
            assert!(stdout_str.contains("📥 check_statement: start for stmt tag 3")); // FuncDecl main
            assert!(stdout_str.contains("📥 check_statement: start for stmt tag 4")); // VarDecl ctx
            assert!(stdout_str.contains("✅ check_statement: successfully verified stmt tag 4"));
            assert!(stdout_str.contains("scope_insert: bound variable 'n' to type Struct(\"BrandedNode_ctx\", Some(\"ctx\"))"));
            assert!(stdout_str.contains("TypeError at line 10:14: Semantic Error: Cannot assign scratchpad-allocated view to field of branded struct Struct(\"BrandedNode_ctx\", Some(\"ctx\"))"));
        })
        .unwrap()
        .join()
        .unwrap();
}

#[test]
fn test_self_hosted_guard_resolver_compilation() {
    std::thread::Builder::new()
        .stack_size(104857600) // 100 MB
        .spawn(|| {
            gust_lexer::init_logging();
            let resolver = gust_lexer::resolver::ModuleResolver::new();
            let fs_impl = gust_lexer::resolver::RealFileSystem;
            let entry_path = std::path::Path::new("compiler/test_runner_entry.gst");

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
                "gust_self_hosted_guard_resolver_{:?}_{}.c",
                thread_id, process_id
            );
            let bin_filename = format!(
                "gust_self_hosted_guard_resolver_{:?}_{}.bin",
                thread_id, process_id
            );

            let c_path = temp_dir.join(&c_filename);
            let bin_path = temp_dir.join(&bin_filename);

            std::fs::write(&c_path, &c_output).expect("Failed to write temporary C file");

            // Compile the generated output directly
            common::compile_c_program(&c_path, &bin_path, &c_output);

            // Execute the self-hosted compiler over compiler/resolver.gst
            let run = std::process::Command::new(&bin_path)
                .arg("compiler/resolver.gst")
                .output()
                .expect("Execution of self-hosted compiler failed");

            let stdout_str = String::from_utf8_lossy(&run.stdout);
            let stderr_str = String::from_utf8_lossy(&run.stderr);

            let _ = std::fs::remove_file(&c_path);
            let _ = std::fs::remove_file(&bin_path);

            if !run.status.success() {
                eprintln!("--- EXECUTION FAILED ---");
                eprintln!("Status: {:?}", run.status);
                eprintln!("STDOUT:\n{}", stdout_str);
                eprintln!("STDERR:\n{}", stderr_str);
            }

            assert!(
                run.status.success(),
                "Self-hosted compilation of resolver.gst failed!\nSTDOUT:\n{}\nSTDERR:\n{}",
                stdout_str,
                stderr_str
            );
        })
        .unwrap()
        .join()
        .unwrap();
}

#[test]
fn test_assignment_lhs_registered_in_resolved_types() {
    let source = "
        func main() {
            mut brand := 10;
            brand = 20;
        }
    ";
    let lexer = Lexer::new(source);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    assert!(parser.errors.is_empty());

    let mut checker = TypeChecker::new();
    let res = checker.check_program(&program);
    assert!(res.is_ok());

    if let Some(gust_lexer::ast::Statement::FunctionDecl { body, .. }) = program.statements.get(0) {
        if let Some(gust_lexer::ast::Statement::Assignment { left, .. }) = body.statements.get(1) {
            let span = left.span();
            let left_type = checker.resolved_types.get(&span);
            assert!(
                left_type.is_some(),
                "LHS of assignment should be registered in resolved_types"
            );
            assert_eq!(left_type.unwrap(), &Type::Int);
        } else {
            panic!("Expected Assignment at index 1");
        }
    } else {
        panic!("Expected FunctionDecl at index 0");
    }
}

#[test]
fn test_e2e_complex_bootstrap_self_hosted() {
    std::thread::Builder::new()
        .stack_size(104857600) // 100 MB
        .spawn(|| {
            gust_lexer::init_logging();
            let resolver = gust_lexer::resolver::ModuleResolver::new();
            let fs_impl = gust_lexer::resolver::RealFileSystem;

            // 1. Resolve and compile the self-hosted compiler (test_runner_entry.gst) using the Rust prototype (gust_v1)
            let entry_path = std::path::Path::new("compiler/test_runner_entry.gst");
            let res = resolver
                .resolve(&entry_path, &fs_impl)
                .expect("Failed to resolve test_runner_entry.gst");
            let (order, mut modules) = res;

            let mut checker_v1 = TypeChecker::new();
            for path in &order {
                if let Some(module) = modules.get(path) {
                    let stem = path.file_stem().unwrap().to_str().unwrap();
                    let is_entry = path == order.last().unwrap();
                    let prefix = if is_entry {
                        "".to_string()
                    } else {
                        format!("{}__", stem)
                    };
                    checker_v1
                        .check_module(&module.program, &prefix)
                        .expect("Typechecking failed on test_runner_entry.gst");
                }
            }

            let mut modules_for_codegen = Vec::new();
            for path in &order {
                if let Some(module) = modules.get_mut(path) {
                    modules_for_codegen.push((path.clone(), module.program.clone()));
                }
            }

            let codegen_v1 = Codegen::new(
                checker_v1.variable_types,
                checker_v1.struct_registry,
                checker_v1.function_registry,
                checker_v1.enum_registry,
                checker_v1.resolved_names,
                checker_v1.resolved_types,
            );
            let c_output_v2 = codegen_v1.generate(&modules_for_codegen);

            // Write the self-hosted compiler C output to disk in temp dir
            let temp_dir = std::env::temp_dir();
            let thread_id = std::thread::current().id();
            let process_id = std::process::id();

            let gust_v2_c_filename = format!("gust_v2_{:?}_{}.c", thread_id, process_id);
            let gust_v2_bin_filename = format!("gust_v2_bin_{:?}_{}", thread_id, process_id);
            let gust_v2_c_path = temp_dir.join(&gust_v2_c_filename);
            let gust_v2_bin_path = temp_dir.join(&gust_v2_bin_filename);

            std::fs::write(&gust_v2_c_path, &c_output_v2).expect("Failed to write gust_v2 C file");

            // Compile gust_v2 binary using host C compiler
            let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap_or_else(|_| ".".to_string());
            let runtime_path = std::path::Path::new(&manifest_dir).join("src/runtime.c");

            let cc_compiler = std::env::var("CC").unwrap_or_else(|_| "cc".to_string());
            let mut cmd = std::process::Command::new(&cc_compiler);
            cmd.arg(&runtime_path);
            cmd.arg(&gust_v2_c_path);
            if std::env::var("GUST_NO_SANITIZERS").is_err() {
                cmd.arg("-fsanitize=address,undefined");
            }
            let compile_output = cmd
                .arg("-o")
                .arg(&gust_v2_bin_path)
                .output()
                .expect("C compiler compilation of gust_v2 failed");

            assert!(
                compile_output.status.success(),
                "C compilation of gust_v2 failed:\n{}",
                String::from_utf8_lossy(&compile_output.stderr)
            );

            // 2. Compile compiler/e2e_complex_bootstrap_target.gst using gust_v2_bin_path
            let run_gust_v2 = std::process::Command::new(&gust_v2_bin_path)
                .arg("compiler/e2e_complex_bootstrap_target.gst")
                .output()
                .expect("Compilation of e2e_complex_bootstrap_target.gst using gust_v2 failed");

            assert!(
                run_gust_v2.status.success(),
                "Compilation of e2e_complex_bootstrap_target.gst using gust_v2 failed:\nSTDOUT:\n{}\nSTDERR:\n{}",
                String::from_utf8_lossy(&run_gust_v2.stdout),
                String::from_utf8_lossy(&run_gust_v2.stderr)
            );

            let c_output_target_raw =
                String::from_utf8(run_gust_v2.stdout).expect("Invalid UTF-8 from gust_v2 compilation");
            let c_output_target = filter_output_c_code(&c_output_target_raw);

            // 3. Prepend core_headers.h and write clean C output to target_c_path
            let mut final_c_code = String::new();
            final_c_code.push_str("#include \"runtime/core_headers.h\"\n\n");
            final_c_code.push_str(&c_output_target);

            let target_c_filename = format!("target_{:?}_{}.c", thread_id, process_id);
            let target_bin_filename = format!("target_bin_{:?}_{}", thread_id, process_id);
            let target_c_path = temp_dir.join(&target_c_filename);
            let target_bin_path = temp_dir.join(&target_bin_filename);

            std::fs::write(&target_c_path, &final_c_code).expect("Failed to write target C file");

            // 4. Compile the target executable against src/runtime.c and the clean C file
            let mut cmd2 = std::process::Command::new(&cc_compiler);
            cmd2.arg(&runtime_path);
            cmd2.arg(&target_c_path);
            cmd2.arg("-Isrc"); // include path to find runtime/core_headers.h
            if std::env::var("GUST_NO_SANITIZERS").is_err() {
                cmd2.arg("-fsanitize=address,undefined");
            }
            let compile_target_output = cmd2
                .arg("-o")
                .arg(&target_bin_path)
                .output()
                .expect("C compiler compilation of target executable failed");

            assert!(
                compile_target_output.status.success(),
                "C compilation of target executable failed:\n{}",
                String::from_utf8_lossy(&compile_target_output.stderr)
            );

            // 5. Run the compiled executable and assert the exact expected outputs
            let run_target = std::process::Command::new(&target_bin_path)
                .output()
                .expect("Execution of compiled target executable failed");

            assert!(
                run_target.status.success(),
                "Execution of compiled target executable failed:\nSTDOUT:\n{}\nSTDERR:\n{}",
                String::from_utf8_lossy(&run_target.stdout),
                String::from_utf8_lossy(&run_target.stderr)
            );

            let stdout_str = String::from_utf8(run_target.stdout).expect("Invalid UTF-8 from target execution");

            // Expected outputs from e2e_complex_bootstrap_target.gst
            let expected_output = "Active: E2E_Bootstrap\n3\n1";
            assert_eq!(stdout_str.trim(), expected_output.trim());

            // Clean up temporary files
            let _ = std::fs::remove_file(&gust_v2_c_path);
            let _ = std::fs::remove_file(&gust_v2_bin_path);
            let _ = std::fs::remove_file(&target_c_path);
            let _ = std::fs::remove_file(&target_bin_path);
        })
        .unwrap()
        .join()
        .unwrap();
}





#[test]
        fn test_nested_same_brands_accepted() {
            let source = "
                func main() {
                    mut ctx := os.Arena.New();
                    defer ctx.Free();
                    mut vec: Vector[Vector[str, ctx], ctx] := os.VectorNew(ctx);
                }
            ";
            assert!(check_program(source).is_ok());
        }

        #[test]
        fn test_generic_branded_struct_mismatched_field_rejected() {
            let source = "
                type Container[T, ctx] struct {
                    value: T
                }
                func main() {
                    mut innerCtx := os.Arena.New();
                    defer innerCtx.Free();
                    mut outerCtx := os.Arena.New();
                    defer outerCtx.Free();
                    mut vec: Container[Vector[str, innerCtx], outerCtx] := empty[Container[Vector[str, innerCtx], outerCtx]];
                }
            ";
            let res = check_program(source);
            assert!(res.is_err());
            let err = res.unwrap_err();
            assert_eq!(err.kind, TypeErrorKind::BrandLifetimeViolation);
            assert!(err.message.contains("Brand Nesting") || err.message.contains("Mismatched nested brand") || err.message.contains("Brand Nesting Restriction violation"));
        }



        #[test]
fn test_os_system_type_checking() {
    let source = "
        func main() {
            mut code := os.System(\"echo 'test'\");
        }
    ";
    assert!(check_program(source).is_ok());
}
