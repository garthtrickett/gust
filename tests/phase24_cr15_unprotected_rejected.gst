import "stdlib_s1_mutex_guard_generic_derivation_module.gst" as sync;

type Counter struct {
    value: int
}

func main() int {
    mut counter: Counter;
    mut owner := sync.lock(&counter);
    return 0;
}
