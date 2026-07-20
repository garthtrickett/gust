func route_architecture_sum(changed_flag: bool, changed_left: int, changed_right: int) int {
    return changed_left + changed_right;
}

func route_architecture_forward(changed_flag: bool, changed_left: int, changed_right: int) int {
    return route_architecture_sum(changed_flag, changed_left, changed_right);
}

func main() int {
    return route_architecture_forward(false, 17, 29);
}
