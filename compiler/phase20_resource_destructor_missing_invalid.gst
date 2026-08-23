#[linear]
#[destructor(missing_cleanup)]
#[opaque]
type MissingCleanup struct {
    token: int
}

func main() int {
    return 0;
}
