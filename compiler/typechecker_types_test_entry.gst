import "ast.gst" as ast;
import "typechecker.gst" as typechecker;
import "lexer.gst" as lexer;
import "parser.gst" as parser;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut env := typechecker.env_new(ctx);

    // 1. Monomorphize Vector[int, ctx]
    mut vec_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    vec_args.Push(typechecker.make_type_int());
    vec_args.Push(typechecker.make_type_struct("ctx", "", ctx));

    mut vec_res := typechecker.monomorphize(&env, "std.Vector", vec_args, ctx);
     if vec_res.tag == 0 {
         mut concrete_t := vec_res.Ok.val;
         os.LogStr(std.Concat("Monomorphized Vector name: ", concrete_t.Struct.struct_name));

         guard layout := env.struct_registry.Get(concrete_t.Struct.struct_name) else {
             return;
         }
         os.LogInt(layout.fields.len);
     } else {
         os.LogStr("Vector monomorphization failed");
     }

    // 2. Parse and Register Custom Enum Template Result[T, ctx]
    mut l: lexer.Lexer[ctx];
    lexer.init_lexer(&l, "type Result[T, ctx] enum { Ok { val: T }, Err { val: int } }");

    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &l, ctx);

    mut prog := parser.parse_program(&p, ctx);
    unsafe {
        mut statements_vec := &ctx[prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
        typechecker.env_pre_register_statement(&env, (*statements_vec)[0], ctx);
    }

    // Monomorphize Result[str, ctx]
    mut res_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    res_args.Push(typechecker.make_type_str());
    res_args.Push(typechecker.make_type_struct("ctx", "", ctx));

    mut mono_res := typechecker.monomorphize(&env, "Result", res_args, ctx);
    if mono_res.tag == 0 {
        mut concrete_t := mono_res.Ok.val;
        os.LogStr(std.Concat("Monomorphized Result name: ", concrete_t.Struct.struct_name));

        guard parent_layout := env.struct_registry.Get(concrete_t.Struct.struct_name) else {
            return;
        }
        os.LogInt(parent_layout.fields.len);

        // Verify sub-variant structure
        guard ok_variant_t := parent_layout.fields.Get("Ok") else {
            return;
        }
        guard ok_layout := env.struct_registry.Get(ok_variant_t.Struct.struct_name) else {
            return;
        }
        os.LogStr(std.Concat("Ok variant field type tag: ", std.FormatInt(ok_layout.fields.Get("val").Val.tag)));
    } else {
        os.LogStr("Result monomorphization failed");
    }
}
