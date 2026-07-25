// Future positive fixture: typed non-capturing function reference call.
func add_one(value: int) int {
    return value + 1;
}

func main() int {
    mut target := add_one;
    return target(6);
}