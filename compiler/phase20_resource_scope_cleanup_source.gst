import "phase20_resource_scope_cleanup_module.gst" as resource;

type CleanupChoice enum {
    First,
    Second
}

func nested_cleanup() {
    mut outer := resource.acquire(1);
    if 1 {
        mut inner := resource.acquire(2);
    }
}

func aggregate_cleanup() {
    mut box: resource.HandleBox;
    box.first = resource.acquire(3);
    box.second = resource.acquire(4);
}

func early_return_cleanup() int {
    mut resource_on_return := resource.acquire(5);
    return 9;
}

func scheduled_cleanup() {
    mut scheduled := resource.acquire(6);
    defer resource.consume(scheduled);
}

func loop_cleanup() {
    mut count := 0;
    while count < 1 {
        mut loop_resource := resource.acquire(7);
        count = count + 1;
    }
}

func match_cleanup() {
    mut choice: CleanupChoice;
    unsafe {
        choice.tag = 0;
    }
    match choice {
        First => {
            mut first_case := resource.acquire(8);
        }
        Second => {
            mut second_case := resource.acquire(9);
        }
    }
}

func manual_cleanup() {
    mut manual := resource.acquire(10);
    resource.consume(manual);
}

func main() int {
    nested_cleanup();
    aggregate_cleanup();
    os.LogInt(early_return_cleanup());
    scheduled_cleanup();
    loop_cleanup();
    match_cleanup();
    manual_cleanup();
    return 0;
}
