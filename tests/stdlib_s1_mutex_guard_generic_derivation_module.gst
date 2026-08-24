#[linear]
#[destructor(release_mutex_guard)]
#[opaque]
type MutexGuard[T, ctx] struct {
    mutex: &std.Mutex[T, ctx],
    protected: *T
}

#[private]
func release_mutex_guard(owner: MutexGuard[T, ctx]) {
    // Signature-only probe: raw Mutex lifecycle calls remain compiler-owned.
}

func lock(mutex: &std.Mutex[T, ctx]) MutexGuard[T, ctx] {
    // CR-15 is reached while substituting this generic result shape, before a
    // real implementation may acquire the Mutex.
    mut owner: MutexGuard[T, ctx];
    owner.mutex = mutex;
    return owner;
}

func get(owner: &MutexGuard[T, ctx]) &T {
    unsafe {
        return &(*owner.protected);
    }
}
