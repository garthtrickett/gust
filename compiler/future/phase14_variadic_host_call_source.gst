// Future positive fixture: allowlisted variadic host ABI.
extern func printf(format: str, ...) int;

func main() int {
    unsafe {
        return printf("%d\n", 7);
    }
}