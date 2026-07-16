extern func gust_unapproved_runtime(value: int) int;

func main() int {
    unsafe {
        return gust_unapproved_runtime(1);
    }
}