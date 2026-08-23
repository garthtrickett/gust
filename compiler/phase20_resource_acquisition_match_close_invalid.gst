import "phase20_resource_enforcement_module.gst" as resource;

type Choice enum {
    First,
    Second
}

func main() int {
    mut handle := resource.acquire();
    mut choice: Choice;
    unsafe {
        choice.tag = 0;
    }
    match choice {
        First => {
        }
        Second => {
            resource.consume(handle);
        }
    }
    return 0;
}
