
        import "token.gst" as token;
        import "ast.gst" as ast;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut strings: std.Vector[str, ctx] := std.VectorNew(ctx);
            strings.Push("hello");
            strings.Push("world");
            mut joined := ast.ast_join_strings(strings, ", ", ctx);
            os.LogStr(joined);

            mut fields: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);
            mut f: ast.FieldDef[ctx];
            f.name = "my_field";
            f.field_type.tag = 0;
            fields.Push(f);
            mut fields_str := ast.ast_join_fields(fields, 1, ctx);
            os.LogStr(fields_str);

            mut params: std.Vector[ast.Parameter[ctx], ctx] := std.VectorNew(ctx);
            mut param: ast.Parameter[ctx];
            param.name = "my_param";
            param.param_type.tag = 1;
            params.Push(param);
            mut params_str := ast.ast_join_params(params, 1, ctx);
            os.LogStr(params_str);
        }
    