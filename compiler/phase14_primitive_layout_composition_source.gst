func phase14_mix(flag: bool, left: int, right: int) int {
    mut value := left + right;
    if flag {
        value = value * 2;
    } else {
        value = value - 1;
    }
    return value;
}

func main() int {
    return phase14_mix(true, 11, 12);
}