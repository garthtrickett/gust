func main() {
    mut not_vec := 123;
    mut bad_lookup := not_vec.get_opt(0);
    match bad_lookup {
        Some { val } => {
            os.LogInt(*val);
        }
        None => {
            os.LogStr("None");
        }
    }
}