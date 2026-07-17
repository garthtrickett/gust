extern func toupper(value: int) int;

func main() int {
    unsafe {
        return toupper(97);
    }
}