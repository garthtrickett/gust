unsafe func privileged_value() int {
    return 7;
}

func main() {
    mut got := privileged_value();
    os.LogInt(got);
}