// Future positive fixture: typed dynamic symbol lookup with lifetime proof.
extern func dlopen(path: str, flags: int) *byte;
extern func dlsym(handle: *byte, symbol: str) *byte;

func main() int {
    unsafe {
        mut handle := dlopen("libc.so", 1);
        mut symbol := dlsym(handle, "abs");
    }
    return 0;
}