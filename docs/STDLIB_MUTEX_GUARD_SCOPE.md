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

The final roadmap misuse case is the raw double unlock. S1.9 documented the
accepted explicit-unsafe limitation; S1.12 adds a compile-only witness after
CR-16 registration. Neither patch adds a Mutex-specific compiler rule.

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

### Registration and compile-only witness

S1.9 initially could not add its raw-unlock fixture because the compiler-owned
raw-Mutex inventory rejected the unregistered `L0 U1` site. PR #357, merged as
`6b657cb42f485207480d295a86a248630a1a12fa`, registered that exact successor.
It derives predecessor totals from the live tree, supporting both sides of the
S1.11 removal. CR-16's registration request is resolved.

S1.12 consumes that admission with
`tests/stdlib_s1_mutex_guard_scope_raw_double_unlock.gst`, rechecking the phase's
residue rather than changing unsafe semantics. The existing scope guard:

- requires MIR-to-C compilation to succeed;
- inspects the generated entry function before its explicit return for exactly
  one raw unlock followed by exactly one cleanup of the guard owner;
- confirms that the emitted destructor itself calls the raw unlock once;
- checks the generated C with the host compiler in syntax-only mode;
- requires native compilation to produce an artifact, without executing it.

**This program must never run.** The generic positive runner executes its
fixtures, so this witness uses direct compilation commands. Inversions ensure
that a declaration, the destructor's own raw call, or an unreachable cleanup
suffix after `return` cannot substitute for the two calls in the entry path.

The compiler registry's historical `compile_fail` role label is not a semantic
expectation. Requiring this accepted explicit-unsafe program to reject would
misstate the documented limitation. The registry is unchanged by the Stdlib
patch; the original holdout outside the repository remains historical evidence.
