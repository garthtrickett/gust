func local_binding_read_provenance_metadata() int {
    mut value := 2;
    return value;
}

func main() {
    mut result := local_binding_read_provenance_metadata();
    os.Exit(result);
}