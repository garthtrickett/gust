import "phase20_resource_enforcement_module.gst" as resource;

func main() int {
    mut handle := resource.acquire();
    mut close_now := 0;
    if close_now {
        resource.consume(handle);
    }
    return 0;
}
