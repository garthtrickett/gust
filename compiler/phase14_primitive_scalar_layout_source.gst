func phase14_choose(flag: bool, left: int, right: int) int {
    if flag {
        return left;
    } else {
        return right;
    }
}

func main() int {
    return phase14_choose(true, 42, 7);
}