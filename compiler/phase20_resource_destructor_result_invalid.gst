#[linear]
#[destructor(destroy_with_result)]
#[opaque]
type ResultCleanup struct {
    token: int
}

#[private]
func destroy_with_result(resource: ResultCleanup) int {
    return 1;
}

func main() int {
    return 0;
}
