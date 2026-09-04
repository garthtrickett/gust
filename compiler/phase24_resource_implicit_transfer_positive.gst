import "phase24_resource_implicit_transfer_module.gst" as resource;

func main() int {
    mut source := resource.acquire_ticket(71);
    mut destination := source;
    mut observed := resource.read_ticket(&destination);
    return observed - 71;
}
