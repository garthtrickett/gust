// Future positive fixture: mutually recursive scalar functions.
func is_even(value: int) int {
    if value > 0 {
        return is_odd(value - 1);
    }
    return 1;
}

func is_odd(value: int) int {
    if value > 0 {
        return is_even(value - 1);
    }
    return 0;
}

func main() int {
    return is_even(4);
}