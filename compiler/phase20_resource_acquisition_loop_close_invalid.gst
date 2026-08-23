import "phase20_resource_enforcement_module.gst" as resource;

func main() int {
    mut handle := resource.acquire();
    mut close_now := 0;
    while close_now {
        resource.consume(handle);
        close_now = 0;
    }
    return 0;
}
