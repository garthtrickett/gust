#[linear]
#[destructor(destroy_unsafe)]
#[opaque]
type UnsafeCleanup struct {
    token: int
}

#[private]
unsafe func destroy_unsafe(resource: UnsafeCleanup) {
}

func main() int {
    return 0;
}
