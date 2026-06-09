use gust_lexer::lexer::Lexer;
use gust_lexer::parser::Parser;
use gust_lexer::typechecker::TypeChecker;

fn check_program(source: &str) -> Result<(), String> {
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
    assert!(res.unwrap_err().contains("already been moved"));
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
    assert!(
        res.unwrap_err()
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

    // If it is an error, print it clearly inside a panic so we can diagnose it [1]
    if let Err(ref err) = res {
        panic!(
            "\n\n🔍 DIAGNOSTIC: Compiler returned this error:\n{}\n\n",
            err
        );
    }

    assert!(res.is_err());
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
    assert!(
        res.unwrap_err()
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
    assert!(
        res.unwrap_err()
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
    assert!(
        res.unwrap_err()
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
    assert!(res.unwrap_err().contains("os.LogInt expects an Int/Byte"));
}
