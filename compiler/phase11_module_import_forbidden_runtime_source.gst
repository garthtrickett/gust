extern func system(command: int) int;

func main() int {
    unsafe {
        return system(1);
    }
}