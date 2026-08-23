import "phase20_resource_enforcement_module.gst" as resource;

func swallow(handle: resource.Handle) {
}

func main() int {
    swallow(resource.acquire());
    return 0;
}
