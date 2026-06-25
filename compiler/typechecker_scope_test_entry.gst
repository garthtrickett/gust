import "ast.gst" as ast;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut root_idx := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    mut t_int: ast.Type[ctx];
    unsafe {
        t_int.tag = 0; // Int
    }

    typechecker.scope_insert(root_idx, "x", t_int, ctx);

    mut child_idx := typechecker.scope_new(root_idx, ctx);

    mut t_bool: ast.Type[ctx];
    unsafe {
        t_bool.tag = 2; // Bool
    }

    typechecker.scope_insert(child_idx, "y", t_bool, ctx);

    mut t_byte: ast.Type[ctx];
    unsafe {
        t_byte.tag = 1; // Byte
    }
    typechecker.scope_insert(child_idx, "x", t_byte, ctx);

    mut look_x_root := typechecker.scope_lookup(root_idx, "x", ctx);
    os.LogInt(look_x_root.tag);

    mut look_y_root := typechecker.scope_lookup(root_idx, "y", ctx);
    os.LogInt(look_y_root.tag);

    mut look_x_child := typechecker.scope_lookup(child_idx, "x", ctx);
    os.LogInt(look_x_child.tag);

    mut look_y_child := typechecker.scope_lookup(child_idx, "y", ctx);
    os.LogInt(look_y_child.tag);
}
