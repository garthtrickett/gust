func local_binding_read() int {
    mut value := 2;
    return value;
}

func main() {
    mut result := local_binding_read();
    os.Exit(result);
}