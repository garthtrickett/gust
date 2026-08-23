import "phase20_resource_enforcement_module.gst" as resource;

func main() int {
    mut handle := resource.acquire();
    return handle.token;
}
