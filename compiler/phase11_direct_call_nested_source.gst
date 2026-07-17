func phase11_sum_with_flag(flag: bool, left: int, right: int) int {
    return left + right;
}

func phase11_forward_sum(flag: bool, left: int, right: int) int {
    return phase11_sum_with_flag(flag, left, right);
}

func main() int {
    return phase11_forward_sum(true, 20, 28);
}