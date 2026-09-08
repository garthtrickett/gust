type Phase13MultiModulePair struct {
    left: int,
    right: int
}

func widen(pair: Phase13MultiModulePair) int {
    return pair.left + pair.right;
}

func lift(value: int) int {
    return value + 1;
}
