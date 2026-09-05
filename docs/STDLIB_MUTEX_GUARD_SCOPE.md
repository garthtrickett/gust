# MutexGuard Scope and Resource Evidence

Patch S1.9 validates the safe `sync.lock` / `sync.get` surface delivered by
S1.8. It adds no synchronization, resource, move, MIR, ABI, or backend
semantics.

## Positive matrix

`tests/stdlib_s1_mutex_guard_scope.gst` exercises one acquisition through each
required form: normal scope exit, early return, nested scope, error return,
explicit guard move, transfer into a helper, and return of a guard where its
brand remains legal. The fixture reacquires the same mutex after each form and
must print `1` through `7`, followed by a final `7`, on both MIR-to-C and
Cranelift. A missing cleanup would deadlock a later acquisition; the inherited
S1.8 one-lock/one-unlock-body check continues to pin the cleanup implementation.

## Compile-fail matrix

The focused guard requires rejection before execution for:

- an attempted copy that would leave the original owner usable;
- an attempted double release through the private cleanup function;
- use after an explicit move;
- placing one acquisition into two owner fields;
- constructing or initializing the opaque guard outside its module.

The final roadmap misuse case is the raw double unlock. It is **documented
below from a live-compiler probe rather than pinned by a fixture in this patch**,
for the reason given in that section. S1.9 does not add a Mutex-specific compiler
rule.

## Raw double-unlock limitation

**The limitation stands.** Probed on the live compiler at main
`5185fbc4cc6ca537736f9a9f1af2dfe59e174ad1`, after Patch 24.2f closed the implicit
linear-Resource transfer gap. This program compiles and links:

```gust
mut owner := sync.lock(&mutex);
unsafe {
    mutex.Unlock();
}
return 0;
```

The generated C contains **both** the explicit raw unlock and the guard's own
scope-exit cleanup for `owner`, so the acquisition is released twice at runtime:

```c
os_Arena_Free(&(arena));
stdlib_s1_mutex_guard_generic_derivation_module__release_mutex_guard_protected_MutexGuard_Counter_arena(owner);
```

This is the outcome the roadmap anticipated, and S1.9 records it rather than
fixing it. Two properties make it a documented limitation rather than a hole in
the safe surface:

- it requires an explicit `unsafe` block, which is the language's sanctioned
  escape hatch and already means the author has taken responsibility; and
- nothing in the safe `sync.lock` / `sync.get` surface can reach
  `mutex.Unlock()`. Every misuse expressible in safe code is rejected, and the
  five compile-fail classes above are the evidence.

Closing it would require a Mutex-aware compiler rule, which is neither this
lane's to write nor, on current evidence, obviously correct: `unsafe` exists
precisely so the compiler stops arguing.

### Why no fixture pins this in S1.9

A fixture asserting the above must contain a raw `mutex.Unlock()` call. The raw
`Mutex.Lock`/`Unlock` inventory across the repository is byte-pinned by the
Cranelift-owned `guard-cranelift-phase20-unsafe-mutex-migration-contract`, whose
authority lives in `scripts/cranelift_feature_registry.json`. Adding the fixture
adds the 35th raw call site and fails that guard:

    raw Mutex call-site classification drifted: actual={... 'tests/stdlib_s1_mutex_guard_scope_raw_double_unlock.gst': {'Lock': 0, 'Unlock': 1}}

Removing the fixture returns the inventory to its pinned state and the contract
passes, so this is the sole cause. Registering a new raw call site is a
Cranelift-owned registry successor — the same shape as the one S1.8 received —
and `AGENTS.md` makes that a coordination request rather than a local edit. The
fixture is preserved and lands in a follow-up once that row exists. The
limitation itself is fully recorded here, which is what the roadmap directed.
