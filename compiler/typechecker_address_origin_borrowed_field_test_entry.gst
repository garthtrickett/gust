import "typechecker.gst" as typechecker;

type Step51AddressOriginFieldNode struct {
    val: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut node: Step51AddressOriginFieldNode;
    node.val = 17;
    mut field_value_step51 := node.val;
    mut field_ref_step51 := &node.val;

    if field_value_step51 != 17 {
        os.LogStr("Error: borrowed field value sanity check failed");
        os.Exit(1);
    }

    unsafe {
        if (*field_ref_step51) != 17 {
            os.LogStr("Error: borrowed field address sanity check failed");
            os.Exit(1);
        }
    }

    mut borrowed_field_value_origin := typechecker.address_origin_record_for_borrowed_field_value("node", "val", ctx);
    if typechecker.address_origin_record_is_borrowed_field(borrowed_field_value_origin) != 1 {
        os.LogStr("Error: borrowed field value was not classified as borrowed_field");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_borrowed_field_value(borrowed_field_value_origin) != 1 {
        os.LogStr("Error: borrowed field value was not classified as field value");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_borrowed_field_address(borrowed_field_value_origin) != 0 {
        os.LogStr("Error: borrowed field value was incorrectly classified as field address");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_container_element(borrowed_field_value_origin) != 0 {
        os.LogStr("Error: borrowed field value was incorrectly classified as container element");
        os.Exit(1);
    }

    mut borrowed_field_address_origin := typechecker.address_origin_record_for_address_of_borrowed_field("node", "val", ctx);
    if typechecker.address_origin_record_is_borrowed_field(borrowed_field_address_origin) != 1 {
        os.LogStr("Error: borrowed field address was not classified as borrowed_field");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_borrowed_field_address(borrowed_field_address_origin) != 1 {
        os.LogStr("Error: borrowed field address was not classified as field address");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_borrowed_field_value(borrowed_field_address_origin) != 0 {
        os.LogStr("Error: borrowed field address was incorrectly classified as field value");
        os.Exit(1);
    }

    mut borrowed_field_debug := typechecker.address_origin_record_debug_string(borrowed_field_address_origin, ctx);
    if std.str_find(borrowed_field_debug, "borrowed_field") == 0 - 1 {
        os.LogStr("Error: borrowed field debug string missing borrowed_field kind");
        os.LogStr(borrowed_field_debug);
        os.Exit(1);
    }
    if std.str_find(borrowed_field_debug, "borrowed.field.address:node.val") == 0 - 1 {
        os.LogStr("Error: borrowed field debug string missing address label");
        os.LogStr(borrowed_field_debug);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: borrowed_field address-origin metadata helpers verified!");
}