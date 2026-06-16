import "ast.gst" as ast;
import "token.gst" as token;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;
import "codegen.gst" as codegen;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env := typechecker.env_new(ctx);
    
    mut c: codegen.Codegen[ctx];
    codegen.init_codegen(&c, &env);

    // 1. Test primitive types
    mut t_int: ast.Type[ctx];
    t_int.tag = 0; // Int
    mut init_int := codegen.codegen_gen_type_aware_initializer(t_int, &env, ctx);
    os.LogStr(init_int); // Expected: 0

    // 2. Test Index type
    mut t_index: ast.Type[ctx];
    t_index.tag = 7; // Index
    t_index.Index.struct_name = "Node";
    t_index.Index.brand = empty[Index[str, ctx]];
    mut init_index := codegen.codegen_gen_type_aware_initializer(t_index, &env, ctx);
    os.LogStr(init_index); // Expected: 0xFFFFFFFF

    // 3. Test RawPointer type
    mut t_ptr: ast.Type[ctx];
    t_ptr.tag = 9; // RawPointer
    mut inner_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    t_ptr.RawPointer.inner = inner_idx;
    ctx[t_ptr.RawPointer.inner].tag = 0; // Int
    mut init_ptr := codegen.codegen_gen_type_aware_initializer(t_ptr, &env, ctx);
    os.LogStr(init_ptr); // Expected: NULL

    // 4. Register and test a custom struct Point { x: int, y: int }
    mut l: lexer.Lexer[ctx];
    lexer.init_lexer(&l, "type Point struct { y: int, x: int }");

    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &l, ctx);

    mut prog := parser.parse_program(&p, ctx);
    unsafe {
        mut statements_vec := &ctx[prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
        typechecker.env_pre_register_statement(&env, (*statements_vec)[0], ctx);
    }

    mut t_point: ast.Type[ctx];
    t_point.tag = 8; // Struct
    t_point.Struct.struct_name = "Point";
    t_point.Struct.brand = empty[Index[str, ctx]];

    mut init_point := codegen.codegen_gen_type_aware_initializer(t_point, &env, ctx);
    os.LogStr(init_point); // Expected: ((Point){ .x = 0, .y = 0 }) (alphabetically sorted!)
}