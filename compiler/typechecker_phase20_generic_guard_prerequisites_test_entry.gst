import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func check_reference_capture_provenance(kind: int, expect_error: int, ctx: &Arena) {
    mut value_type := typechecker.make_type_struct("Phase20GuardValue", "ctx", ctx);
    mut reference_type := typechecker.make_type_reference(value_type, "ctx", ctx);

    mut capture_layout: typechecker.StructLayout[ctx];
    unsafe {
        capture_layout.brand = empty[Index[str, ctx]];
        capture_layout.fields = std.HashMapNew(ctx);
    }
    capture_layout.fields.Insert("value", reference_type);

    mut capture_type := typechecker.make_type_struct("Phase20ReferenceCapture", "ctx", ctx);
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env, "Phase20ReferenceCapture", capture_layout, ctx);
    typechecker.scope_insert(scope, "capture", capture_type, ctx);
    env.variable_types.Insert("capture", capture_type);
    typechecker.scope_insert(scope, "source", reference_type, ctx);
    env.variable_types.Insert("source", reference_type);

    mut provenance: typechecker.ExpressionProvenance[ctx];
    if kind == 0 {
        provenance = typechecker.expression_provenance_raw_derived(reference_type, ctx);
    } else if kind == 1 {
        provenance = typechecker.expression_provenance_sandbox_derived(reference_type, ctx);
    } else {
        typechecker.env_record_safe_parameter_provenance(&env, "source", reference_type, ctx);
        guard recorded := env.variable_provenance.Get("source") else {
            os.LogStr("Error: branded reference parameter did not receive safe provenance");
            os.Exit(1);
        }
        provenance = recorded;
    }
    typechecker.env_record_variable_provenance(&env, "source", provenance, ctx);

    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, "capture.value = source;");
    mut parse: parser.Parser[ctx];
    parser.init_parser(&parse, &lex, ctx);
    mut statement := parser.parse_statement(&parse, ctx);
    typechecker.check_statement(statement, &env, scope, ctx);

    if expect_error == 1 {
        if len(env.errors) == 0 {
            os.LogStr("Error: unsafe-derived branded reference capture was accepted");
            os.Exit(1);
        }
        if std.str_find(env.errors[0].message, "Non-laundering violation") == 0 - 1 {
            os.LogStr("Error: unsafe-derived branded reference capture emitted the wrong diagnostic");
            os.LogStr(env.errors[0].message);
            os.Exit(1);
        }
    } else if len(env.errors) != 0 {
        os.LogStr("Error: safe same-brand reference parameter capture was rejected");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    check_reference_capture_provenance(0, 1, ctx);
    check_reference_capture_provenance(1, 1, ctx);
    check_reference_capture_provenance(2, 0, ctx);
    os.LogStr("SUCCESS: generic guard prerequisite provenance verified!");
}
