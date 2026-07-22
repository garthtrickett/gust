func main() int {
    mut gate := 1;
    mut base := 6;
    if gate > 0 {
        mut branch_value := base + 7;
        branch_value = branch_value + 1;
        if branch_value > 0 {
            return branch_value;
        } else {
            return base;
        }
    } else {
        mut fallback := base + 2;
        fallback = fallback + 1;
        if fallback > 0 {
            return fallback;
        } else {
            return gate;
        }
    }
}