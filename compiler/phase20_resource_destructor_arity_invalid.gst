#[linear]
#[destructor(destroy_wrong_arity)]
#[opaque]
type WrongArityCleanup struct {
    token: int
}

#[private]
func destroy_wrong_arity(first: WrongArityCleanup, second: WrongArityCleanup) {
}

func main() int {
    return 0;
}
