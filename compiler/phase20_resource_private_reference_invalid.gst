import "phase20_resource_enforcement_module.gst" as resource;

func main() int {
    mut handle := resource.acquire();
    std.Spawn(
        phase20_resource_enforcement_module__destroy_handle,
        move handle
    );
    return 0;
}
