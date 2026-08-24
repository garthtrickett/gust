type ProtectedValue[ctx] struct {
    value: int
}

type ProtectedCapture[ctx] struct {
    value: &ProtectedValue[ctx]
}

#[linear]
#[destructor(destroy_mutex_owner)]
#[opaque]
type MutexOwner[ctx] struct {
    mutex: &std.Mutex[ProtectedValue[ctx], ctx],
    protected: *ProtectedValue[ctx],
    token: int
}

#[linear]
#[destructor(destroy_guard)]
#[opaque]
type Guard[ctx] struct {
    protected: &ProtectedValue[ctx],
    token: int
}

#[private]
func destroy_guard(owner: Guard[ctx]) {
    os.LogInt(owner.token);
}

func acquire(value: &ProtectedValue[ctx], token: int) Guard[ctx] {
    mut owner: Guard[ctx];
    owner.protected = value;
    owner.token = token;
    return owner;
}

func access(owner: &Guard[ctx]) &ProtectedValue[ctx] {
    return owner.protected;
}

func ambiguous_access(first: &Guard[ctx], second: &Guard[ctx]) &ProtectedValue[ctx] {
    return first.protected;
}

func consume(owner: Guard[ctx]) {
    destroy_guard(owner);
}

func sink(value: &ProtectedValue[ctx]) int {
    return value.value;
}

#[private]
func destroy_mutex_owner(owner: MutexOwner[ctx]) {
    unsafe {
        (*owner.mutex).Unlock();
    }
    os.LogInt(owner.token);
}

func acquire_mutex_owner(mutex: &std.Mutex[ProtectedValue[ctx], ctx], token: int) MutexOwner[ctx] {
    mut owner: MutexOwner[ctx];
    unsafe {
        mut raw_value := (*mutex).Lock();
        owner.protected = raw_value;
    }
    owner.mutex = mutex;
    owner.token = token;
    return owner;
}

func mutex_access(owner: &MutexOwner[ctx]) &ProtectedValue[ctx] {
    unsafe {
        return &(*owner.protected);
    }
}
