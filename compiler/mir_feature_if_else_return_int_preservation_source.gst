func if_else_return_int() int {
    if true {
        return 1;
    } else {
        return 2;
    }
}

func main() {
    mut result := if_else_return_int();
    os.Exit(result);
}