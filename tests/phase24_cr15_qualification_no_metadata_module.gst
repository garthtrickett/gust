type Lease[T, ctx] struct {
    mutex: &std.Mutex[T, ctx],
    protected: *T,
    marker: int
}

func enter(mutex: &std.Mutex[T, ctx]) Lease[T, ctx] {
    mut owner: Lease[T, ctx];
    owner.mutex = mutex;
    return owner;
}

func view(owner: &Lease[T, ctx]) &T {
    unsafe {
        return &(*owner.protected);
    }
}
