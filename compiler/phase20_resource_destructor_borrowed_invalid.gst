#[linear]
#[destructor(destroy_borrowed)]
#[opaque]
type BorrowedCleanup struct {
    token: int
}

#[private]
func destroy_borrowed(resource: &BorrowedCleanup) {
}

func main() int {
    return 0;
}
