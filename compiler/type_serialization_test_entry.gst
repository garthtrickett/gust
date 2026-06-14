
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
                t_branded.Struct.brand = os.ArenaAlloc(ctx);
                ctx[t_branded.Struct.brand] = 'connCtx';
                os.LogStr(ast.serialize_type(t_branded, ctx));

                // 4. Raw Pointer Type
                mut t_ptr: ast.Type[ctx];
                t_ptr.tag = 9;
                t_ptr.RawPointer.inner = os.ArenaAlloc(ctx);
                ctx[t_ptr.RawPointer.inner].tag = 0;
                os.LogStr(ast.serialize_type(t_ptr, ctx));

                // 5. Generic Type
                mut t_gen: ast.Type[ctx];
                t_gen.tag = 10;
                t_gen.Generic.name = 'std.Vector';
                t_gen.Generic.args = os.ArenaAlloc(ctx);
                mut args := &ctx[t_gen.Generic.args] as *std.Vector[ast.Type[ctx], ctx];
                *args = std.VectorNew(ctx);

                mut arg1: ast.Type[ctx];
                arg1.tag = 0;
                (*args).Push(arg1);

                mut arg2: ast.Type[ctx];
                arg2.tag = 8;
                arg2.Struct.struct_name = 'ctx';
                arg2.Struct.brand = empty[Index[str, ctx]];
                (*args).Push(arg2);

                os.LogStr(ast.serialize_type(t_gen, ctx));
            }
        