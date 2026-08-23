import "phase20_resource_enforcement_module.gst" as resource;

func main() int {
    mut local_result := resource.same_module_success();
    mut handle := resource.acquire();
    mut observed := resource.read(&handle);
    resource.consume(handle);
    return observed + local_result;
}
