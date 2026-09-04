import "phase24_resource_implicit_transfer_module.gst" as resource;

func main() int {
    mut source := resource.acquire_ticket(71);
    mut destination := source;
    mut observed_source := resource.read_ticket(&source);
    mut observed_destination := resource.read_ticket(&destination);
    return observed_source - observed_destination;
}
