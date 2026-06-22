func check_value(x: int) int {
    if x <= 10 {
        return 1;
    } else if x >= 20 {
        return 2;
    } else {
        return 3;
    }
}

func main() {
    os.LogInt(check_value(5));
    os.LogInt(check_value(25));
    os.LogInt(check_value(15));
}
