import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut surface_lexer_phase21_3: lexer.Lexer[ctx];
    lexer.init_lexer(
        &surface_lexer_phase21_3,
        "#[scoped(workspace_id)] type WorkspaceRow struct { workspace_id: int, value: int } #[scoped(workspace_id)] type MemberRow struct { workspace_id: int, value: int } #[scoped(workspace_id)] type AuditRow struct { workspace_id: int, value: int } func main() int { mut workspace_scope := 7; mut member_scope := 7; mut cross_capability := 1; return query { root WorkspaceRow as workspace; predicate workspace.workspace_id == workspace_scope; join MemberRow as member predicate member.workspace_id == member_scope; nested query { root AuditRow as audit; predicate audit.workspace_id == workspace_scope; terminal 11; }; cross_tenant cross_capability; terminal 37; }; }"
    );
    mut surface_parser_phase21_3: parser.Parser[ctx];
    parser.init_parser(
        &surface_parser_phase21_3, &surface_lexer_phase21_3, ctx
    );
    mut surface_program_phase21_3 := parser.parse_program(
        &surface_parser_phase21_3, ctx
    );
    if len(surface_parser_phase21_3.errors) != 0 {
        os.LogStr("Error: complete Phase 21.3 typed-query surface did not parse");
        os.Exit(1);
    }

    mut surface_statements_phase21_3: std.Vector[ast.Statement[ctx], ctx] :=
        ctx[surface_program_phase21_3.statements];
    if len(surface_statements_phase21_3) != 4 {
        os.LogStr("Error: expected three scoped entities and one function");
        os.Exit(1);
    }
    unsafe {
        mut scoped_index_phase21_3 := 0;
        while scoped_index_phase21_3 < 3 {
            mut scoped_statement_phase21_3 := surface_statements_phase21_3[scoped_index_phase21_3];
            if scoped_statement_phase21_3.tag != 1 ||
               scoped_statement_phase21_3.StructDecl.is_scoped_entity != 1 ||
               std.str_eq(scoped_statement_phase21_3.StructDecl.scope_field, "workspace_id") == 0
            {
                os.LogStr("Error: scoped entity metadata was not preserved");
                os.Exit(1);
            }
            scoped_index_phase21_3 = scoped_index_phase21_3 + 1;
        }

        mut main_statement_phase21_3 := surface_statements_phase21_3[3];
        if main_statement_phase21_3.tag != 3 {
            os.LogStr("Error: expected function after scoped entities");
            os.Exit(1);
        }
        mut main_body_phase21_3 := ctx[main_statement_phase21_3.FunctionDecl.body];
        mut main_statements_phase21_3: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[main_body_phase21_3.statements];
        if len(main_statements_phase21_3) != 4 || main_statements_phase21_3[3].tag != 12 {
            os.LogStr("Error: complete typed-query fixture lost its return statement");
            os.Exit(1);
        }
        mut query_expression_phase21_3 := ctx[main_statements_phase21_3[3].Return.expr];
        if query_expression_phase21_3.tag != 14 {
            os.LogStr("Error: query block did not produce the Query AST variant");
            os.Exit(1);
        }
        mut roots_phase21_3: std.Vector[ast.QueryRoot[ctx], ctx] :=
            ctx[query_expression_phase21_3.Query.roots];
        mut predicates_phase21_3: std.Vector[ast.Expression[ctx], ctx] :=
            ctx[query_expression_phase21_3.Query.predicates];
        mut joins_phase21_3: std.Vector[ast.QueryJoin[ctx], ctx] :=
            ctx[query_expression_phase21_3.Query.joins];
        mut nested_phase21_3: std.Vector[ast.Expression[ctx], ctx] :=
            ctx[query_expression_phase21_3.Query.nested_queries];
        if len(roots_phase21_3) != 1 || len(predicates_phase21_3) != 1 ||
           len(joins_phase21_3) != 1 || len(nested_phase21_3) != 1 ||
           query_expression_phase21_3.Query.cross_tenant_capability ==
               empty[Index[ast.Expression[ctx], ctx]]
        {
            os.LogStr("Error: query clause metadata population drifted");
            os.Exit(1);
        }
        if std.str_eq(roots_phase21_3[0].entity_name, "WorkspaceRow") == 0 ||
           std.str_eq(roots_phase21_3[0].binding_name, "workspace") == 0 ||
           std.str_eq(joins_phase21_3[0].entity_name, "MemberRow") == 0 ||
           std.str_eq(joins_phase21_3[0].binding_name, "member") == 0
        {
            os.LogStr("Error: query root or join identity drifted");
            os.Exit(1);
        }
        if nested_phase21_3[0].tag != 14 ||
           ctx[query_expression_phase21_3.Query.terminal].tag != 1 ||
           ctx[query_expression_phase21_3.Query.terminal].Integer.val != 37
        {
            os.LogStr("Error: nested query or terminal metadata drifted");
            os.Exit(1);
        }
    }

    mut serialized_surface_phase21_3 := ast.serialize_program(
        &surface_program_phase21_3, 0, ctx
    );
    if std.str_find(serialized_surface_phase21_3, "#[scoped(workspace_id)]") == 0 - 1 ||
       std.str_find(serialized_surface_phase21_3, "Root: WorkspaceRow as workspace") == 0 - 1 ||
       std.str_find(serialized_surface_phase21_3, "Join: MemberRow as member") == 0 - 1 ||
       std.str_find(serialized_surface_phase21_3, "Nested:") == 0 - 1 ||
       std.str_find(serialized_surface_phase21_3, "CrossTenant:") == 0 - 1 ||
       std.str_find(serialized_surface_phase21_3, "Terminal:") == 0 - 1
    {
        os.LogStr("Error: typed-query syntax did not survive AST serialization");
        os.Exit(1);
    }

    mut identifier_lexer_phase21_3: lexer.Lexer[ctx];
    lexer.init_lexer(
        &identifier_lexer_phase21_3,
        "func main() int { mut query := 3; return query; }"
    );
    mut identifier_parser_phase21_3: parser.Parser[ctx];
    parser.init_parser(
        &identifier_parser_phase21_3, &identifier_lexer_phase21_3, ctx
    );
    mut identifier_program_phase21_3 := parser.parse_program(
        &identifier_parser_phase21_3, ctx
    );
    if len(identifier_parser_phase21_3.errors) != 0 {
        os.LogStr("Error: contextual query syntax captured an ordinary identifier");
        os.Exit(1);
    }
    mut identifier_top_phase21_3: std.Vector[ast.Statement[ctx], ctx] :=
        ctx[identifier_program_phase21_3.statements];
    unsafe {
        mut identifier_body_phase21_3 := ctx[identifier_top_phase21_3[0].FunctionDecl.body];
        mut identifier_statements_phase21_3: std.Vector[ast.Statement[ctx], ctx] :=
            ctx[identifier_body_phase21_3.statements];
        if ctx[identifier_statements_phase21_3[1].Return.expr].tag != 0 {
            os.LogStr("Error: ordinary query identifier changed AST meaning");
            os.Exit(1);
        }
    }

    os.LogStr("SUCCESS: Phase 21.3 typed-query no-op surface verified!");
}
