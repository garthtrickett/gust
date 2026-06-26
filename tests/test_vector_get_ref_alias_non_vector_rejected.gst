func main() {
    mut not_vec_alias := 123;

    mut bad_ref_alias := std.VectorGetRef(not_vec_alias, 0);
    os.LogInt(*bad_ref_alias);
}