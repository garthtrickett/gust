func phase14_pointer_width_gate(flag: bool, value: int) int {
    if flag {
        return value + 1;
    } else {
        return value - 1;
    }
}

func main() int {
    return phase14_pointer_width_gate(true, 42);
}