import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env := typechecker.env_new(ctx);

    typechecker.env_register_struct_layout_metadata(&env, "main__Plain", 0, 0, "", ctx);
    if typechecker.env_struct_requires_layout_metadata(&env, "main__Plain", ctx) != 0 {
        os.LogStr("Error: plain struct must not require layout metadata");
        os.Exit(1);
    }
    if typechecker.env_struct_layout_abi_is_c(&env, "main__Plain", ctx) != 0 {
        os.LogStr("Error: plain struct layout ABI must not report C");
        os.Exit(1);
    }

    typechecker.env_register_struct_layout_metadata(&env, "main__CLike", 1, 0, "C", ctx);
    if typechecker.env_struct_is_repr_c(&env, "main__CLike", ctx) != 1 {
        os.LogStr("Error: repr-C metadata lookup failed");
        os.Exit(1);
    }
    if typechecker.env_struct_is_packed(&env, "main__CLike", ctx) != 0 {
        os.LogStr("Error: repr-C-only metadata must not imply packed");
        os.Exit(1);
    }
    if typechecker.env_struct_requires_layout_metadata(&env, "main__CLike", ctx) != 1 {
        os.LogStr("Error: repr-C metadata must require layout metadata");
        os.Exit(1);
    }
    if typechecker.env_struct_layout_abi_is_c(&env, "main__CLike", ctx) != 1 {
        os.LogStr("Error: repr-C layout ABI C predicate failed");
        os.Exit(1);
    }

    typechecker.env_register_struct_layout_metadata(&env, "main__Packed", 0, 1, "", ctx);
    if typechecker.env_struct_is_repr_c(&env, "main__Packed", ctx) != 0 {
        os.LogStr("Error: packed-only metadata must not imply repr-C");
        os.Exit(1);
    }
    if typechecker.env_struct_is_packed(&env, "main__Packed", ctx) != 1 {
        os.LogStr("Error: packed metadata lookup failed");
        os.Exit(1);
    }
    if typechecker.env_struct_requires_layout_metadata(&env, "main__Packed", ctx) != 1 {
        os.LogStr("Error: packed metadata must require layout metadata");
        os.Exit(1);
    }

    if typechecker.env_struct_requires_layout_metadata(&env, "main__Missing", ctx) != 0 {
        os.LogStr("Error: missing layout metadata must default to disabled");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: payload-safe layout metadata registry helpers verified!");
}
