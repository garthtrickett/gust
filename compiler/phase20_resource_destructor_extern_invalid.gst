#[linear]
#[destructor(destroy_extern)]
#[opaque]
type ExternCleanup struct {
    token: int
}

#[private]
extern func destroy_extern(resource: ExternCleanup);

func main() int {
    return 0;
}
