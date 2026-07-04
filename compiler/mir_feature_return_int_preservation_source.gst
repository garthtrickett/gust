func return_one() int {
    return 1;
}

func main() {
    mut result := return_one();
    os.Exit(result);
}
