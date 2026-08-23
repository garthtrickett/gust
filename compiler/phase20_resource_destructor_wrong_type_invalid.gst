#[linear]
#[destructor(destroy_wrong_type)]
#[opaque]
type WrongTypeCleanup struct {
    token: int
}

#[private]
func destroy_wrong_type(resource: int) {
}

func main() int {
    return 0;
}
