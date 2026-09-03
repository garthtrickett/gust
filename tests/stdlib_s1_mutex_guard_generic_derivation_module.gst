#[linear]
#[destructor(release_mutex_guard)]
#[opaque]
type MutexGuard[T, ctx] struct {
    mutex: &std.Mutex[T, ctx],
    protected: *T
}

#[private]
func release_mutex_guard(owner: MutexGuard[T, ctx]) {
    unsafe {
        (*owner.mutex).Unlock();
    }
}

func lock(mutex: &std.Mutex[T, ctx]) MutexGuard[T, ctx] {
    mut owner: MutexGuard[T, ctx];
    unsafe {
        owner.protected = (*mutex).Lock();
    }
    owner.mutex = mutex;
    return owner;
}

func get(owner: &MutexGuard[T, ctx]) &T {
    unsafe {
        return &(*owner.protected);
    }
}
