#[linear]
#[destructor(retire_lease)]
#[opaque]
type Lease[T, ctx] struct {
    mutex: &std.Mutex[T, ctx],
    protected: *T,
    marker: int
}

#[private]
func retire_lease(owner: Lease[T, ctx]) {
    unsafe {
        (*owner.mutex).Unlock();
    }
    os.LogInt(owner.marker);
}

func enter(mutex: &std.Mutex[T, ctx]) Lease[T, ctx] {
    mut owner: Lease[T, ctx];
    unsafe {
        owner.protected = (*mutex).Lock();
    }
    owner.mutex = mutex;
    owner.marker = 1;
    os.LogInt(100);
    return owner;
}

func view(owner: &Lease[T, ctx]) &T {
    unsafe {
        return &(*owner.protected);
    }
}
