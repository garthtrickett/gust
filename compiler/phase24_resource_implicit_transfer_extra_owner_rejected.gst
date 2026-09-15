import "phase24_resource_implicit_transfer_module.gst" as resource;

func main() int {
    mut source := resource.acquire_ticket(72);
    mut destination := source;
    mut extra := destination;
    return resource.read_ticket(&destination) - resource.read_ticket(&extra);
}
