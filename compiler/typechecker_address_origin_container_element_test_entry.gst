import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut container_value_origin := typechecker.address_origin_record_for_container_element_value("values", "0", ctx);
    if typechecker.address_origin_record_is_container_element(container_value_origin) != 1 {
        os.LogStr("Error: container element value was not classified as container_element");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_container_element_value(container_value_origin) != 1 {
        os.LogStr("Error: container element value was not classified as element value");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_container_element_address(container_value_origin) != 0 {
        os.LogStr("Error: container element value was incorrectly classified as element address");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_borrowed_field(container_value_origin) != 0 {
        os.LogStr("Error: container element value was incorrectly classified as borrowed field");
        os.Exit(1);
    }

    mut container_address_origin := typechecker.address_origin_record_for_address_of_container_element("values", "0", ctx);
    if typechecker.address_origin_record_is_container_element(container_address_origin) != 1 {
        os.LogStr("Error: container element address was not classified as container_element");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_container_element_address(container_address_origin) != 1 {
        os.LogStr("Error: container element address was not classified as element address");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_container_element_value(container_address_origin) != 0 {
        os.LogStr("Error: container element address was incorrectly classified as element value");
        os.Exit(1);
    }

    mut arena_element_origin := typechecker.address_origin_record_for_container_element_value("ctx", "node_idx", ctx);
    if typechecker.address_origin_record_is_container_element(arena_element_origin) != 1 {
        os.LogStr("Error: arena indexed read metadata was not classified as container_element");
        os.Exit(1);
    }

    mut container_debug := typechecker.address_origin_record_debug_string(container_address_origin, ctx);
    if std.str_find(container_debug, "container_element") == 0 - 1 {
        os.LogStr("Error: container element debug string missing container_element kind");
        os.LogStr(container_debug);
        os.Exit(1);
    }
    if std.str_find(container_debug, "container.element.address:values[0]") == 0 - 1 {
        os.LogStr("Error: container element debug string missing address label");
        os.LogStr(container_debug);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: container_element address-origin metadata helpers verified!");
}