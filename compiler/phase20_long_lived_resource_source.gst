import "phase20_resource_scope_cleanup_module.gst" as resource;

func resource_cycle(token: int) {
    mut outer := resource.acquire(token);
    if 1 {
        mut nested: resource.HandleBox;
        nested.first = resource.acquire(token + 100);
        nested.second = resource.acquire(token + 200);
    }
    mut transferred := resource.acquire(token + 300);
    resource.consume(transferred);
}

func main() int {
    mut cycle := 1;
    while cycle <= 16 {
        resource_cycle(cycle);
        cycle = cycle + 1;
    }
    return 0;
}
