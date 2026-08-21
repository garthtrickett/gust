// Phase 19.5 by-value argument representation, spelling-sensitive arm.
func phase19_argument_length(value: str) int {
    return len(value);
}

func main() int {
    mut a := "phase19";
    return phase19_argument_length(a);
}
