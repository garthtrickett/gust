import "phase20_resource_enforcement_module.gst" as resource;

func main() int {
    mut handle := resource.acquire();
    resource.destroy_handle(move handle);
    return 0;
}
