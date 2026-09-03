import "phase24_cr15_qualification_module.gst" as access;

func unresolved(mutex: &std.Mutex[T, ctx]) access.Lease[T, ctx] {
    return access.enter(mutex);
}

func main() int {
    return 0;
}
