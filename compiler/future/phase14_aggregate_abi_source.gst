// Future positive fixture: aggregate parameter and aggregate return ABI.
type Phase14Pair struct {
    left: int,
    right: int
}

func phase14_pair_swap(value: Phase14Pair) Phase14Pair {
    mut result: Phase14Pair;
    result.left = value.right;
    result.right = value.left;
    return result;
}

func main() int {
    mut pair: Phase14Pair;
    pair.left = 2;
    pair.right = 5;
    mut swapped := phase14_pair_swap(pair);
    return swapped.left + swapped.right;
}