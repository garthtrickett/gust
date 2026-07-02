import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut local_value_step51 := 41;
    mut local_ref_step51 := &local_value_step51;

    if local_value_step51 != 41 {
        os.LogStr("Error: local value sanity check failed");
        os.Exit(1);
    }

    unsafe {
        if (*local_ref_step51) != 41 {
            os.LogStr("Error: local address sanity check failed");
            os.Exit(1);
        }
    }

    mut local_value_origin := typechecker.address_origin_record_for_local_identifier("local_value_step51", ctx);
    if typechecker.address_origin_record_is_local_stack(local_value_origin) != 1 {
        os.LogStr("Error: local value origin was not classified as local_stack");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_local_value(local_value_origin) != 1 {
        os.LogStr("Error: local value origin was not classified as local value");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_local_address(local_value_origin) != 0 {
        os.LogStr("Error: local value origin was incorrectly classified as local address");
        os.Exit(1);
    }

    mut local_address_origin := typechecker.address_origin_record_for_address_of_local_identifier("local_value_step51", ctx);
    if typechecker.address_origin_record_is_local_stack(local_address_origin) != 1 {
        os.LogStr("Error: local address origin was not classified as local_stack");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_local_address(local_address_origin) != 1 {
        os.LogStr("Error: local address origin was not classified as local address");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_local_value(local_address_origin) != 0 {
        os.LogStr("Error: local address origin was incorrectly classified as local value");
        os.Exit(1);
    }

    mut local_value_name := typechecker.address_origin_record_local_name(local_value_origin, ctx);
    if std.str_eq(local_value_name, "local_value_step51") == 0 {
        os.LogStr("Error: local value origin name extraction drifted");
        os.LogStr(local_value_name);
        os.Exit(1);
    }

    mut local_address_name := typechecker.address_origin_record_local_name(local_address_origin, ctx);
    if std.str_eq(local_address_name, "local_value_step51") == 0 {
        os.LogStr("Error: local address origin name extraction drifted");
        os.LogStr(local_address_name);
        os.Exit(1);
    }

    mut local_address_debug := typechecker.address_origin_record_debug_string(local_address_origin, ctx);
    if std.str_find(local_address_debug, "local_stack") == 0 - 1 {
        os.LogStr("Error: local address debug string missing local_stack kind");
        os.LogStr(local_address_debug);
        os.Exit(1);
    }
    if std.str_find(local_address_debug, "local.address:local_value_step51") == 0 - 1 {
        os.LogStr("Error: local address debug string missing address label");
        os.LogStr(local_address_debug);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: local_stack address-origin metadata helpers verified!");
}