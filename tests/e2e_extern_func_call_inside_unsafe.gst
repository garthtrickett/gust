extern func c_add(x: int) int {
    return x;
}

func main() {
    unsafe {
        mut result: int := c_add(41);
        os.LogInt(result);
    }
}