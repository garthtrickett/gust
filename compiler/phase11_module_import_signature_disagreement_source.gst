extern func toupper(value: bool) int;

func main() int {
    unsafe {
        return toupper(true);
    }
}