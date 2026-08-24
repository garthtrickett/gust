extern func phase20_long_lived_concurrent_probe() int;

func main() int {
    unsafe {
        return phase20_long_lived_concurrent_probe();
    }
}
