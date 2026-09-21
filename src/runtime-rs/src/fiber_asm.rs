
// ---- Patch 25.6: fiber.c's assembly, ported verbatim ----
//
// D3: these were never INLINE asm. They are top-level __asm__ blocks of
// pure .text/.global assembly with no operand constraints, no clobbers
// and no interaction with surrounding C -- two functions, four platform
// quadrants each. So this is a copy-paste, not a rewrite: the same
// instructions move from a C file to a Rust one unchanged.
//
// All EIGHT port, not the two CI builds. O2: the platform-naming
// obligation binds the seed, not the runtime, and deleting by
// architecture would delete Apple Silicon since macOS is aarch64.
// Three of the four quadrants remain unbuilt -- a pre-existing
// condition this port must neither worsen nor silently claim to fix.
//
// The macOS underscore variants stay explicit: #[no_mangle] applies the
// platform symbol prefix to FUNCTIONS, but global_asm! is raw text and
// gets no such treatment (P4).

#[cfg(all(target_arch = "x86_64", target_vendor = "apple"))]
core::arch::global_asm!(
    ".text",
    ".global _gust_context_switch",
    "_gust_context_switch:",
    "    pushq %rbp",
    "    pushq %rbx",
    "    pushq %r12",
    "    pushq %r13",
    "    pushq %r14",
    "    pushq %r15",
    "    movq %rsp, (%rdi)",
    "    movq %rsi, %rsp",
    "    popq %r15",
    "    popq %r14",
    "    popq %r13",
    "    popq %r12",
    "    popq %rbx",
    "    popq %rbp",
    "    ret",
    options(att_syntax)
);

#[cfg(all(target_arch = "x86_64", not(target_vendor = "apple")))]
core::arch::global_asm!(
    ".text",
    ".global gust_context_switch",
    "gust_context_switch:",
    "    pushq %rbp",
    "    pushq %rbx",
    "    pushq %r12",
    "    pushq %r13",
    "    pushq %r14",
    "    pushq %r15",
    "    movq %rsp, (%rdi)",
    "    movq %rsi, %rsp",
    "    popq %r15",
    "    popq %r14",
    "    popq %r13",
    "    popq %r12",
    "    popq %rbx",
    "    popq %rbp",
    "    ret",
    options(att_syntax)
);

#[cfg(all(target_arch = "aarch64", target_vendor = "apple"))]
core::arch::global_asm!(
    ".text",
    ".global _gust_context_switch",
    "_gust_context_switch:",
    "    stp x29, x30, [sp, #-16]!",
    "    stp x27, x28, [sp, #-16]!",
    "    stp x25, x26, [sp, #-16]!",
    "    stp x23, x24, [sp, #-16]!",
    "    stp x21, x22, [sp, #-16]!",
    "    stp x19, x20, [sp, #-16]!",
    "    mov x2, sp",
    "    str x2, [x0]",
    "    mov sp, x1",
    "    ldp x19, x20, [sp], #16",
    "    ldp x21, x22, [sp], #16",
    "    ldp x23, x24, [sp], #16",
    "    ldp x25, x26, [sp], #16",
    "    ldp x27, x28, [sp], #16",
    "    ldp x29, x30, [sp], #16",
    "    ret",
);

#[cfg(all(target_arch = "aarch64", not(target_vendor = "apple")))]
core::arch::global_asm!(
    ".text",
    ".global gust_context_switch",
    "gust_context_switch:",
    "    stp x29, x30, [sp, #-16]!",
    "    stp x27, x28, [sp, #-16]!",
    "    stp x25, x26, [sp, #-16]!",
    "    stp x23, x24, [sp, #-16]!",
    "    stp x21, x22, [sp, #-16]!",
    "    stp x19, x20, [sp, #-16]!",
    "    mov x2, sp",
    "    str x2, [x0]",
    "    mov sp, x1",
    "    ldp x19, x20, [sp], #16",
    "    ldp x21, x22, [sp], #16",
    "    ldp x23, x24, [sp], #16",
    "    ldp x25, x26, [sp], #16",
    "    ldp x27, x28, [sp], #16",
    "    ldp x29, x30, [sp], #16",
    "    ret",
);

#[cfg(all(target_arch = "x86_64", target_vendor = "apple"))]
core::arch::global_asm!(
    ".text",
    ".global _gust_fiber_entry_wrapper",
    "_gust_fiber_entry_wrapper:",
    "    movq %r13, %rdi",
    "    callq *%r12",
    "    movq %r14, %rdi",
    "    callq _gust_fiber_exit",
    options(att_syntax)
);

#[cfg(all(target_arch = "x86_64", not(target_vendor = "apple")))]
core::arch::global_asm!(
    ".text",
    ".global gust_fiber_entry_wrapper",
    "gust_fiber_entry_wrapper:",
    "    movq %r13, %rdi",
    "    callq *%r12",
    "    movq %r14, %rdi",
    "    callq gust_fiber_exit",
    options(att_syntax)
);

#[cfg(all(target_arch = "aarch64", target_vendor = "apple"))]
core::arch::global_asm!(
    ".text",
    ".global _gust_fiber_entry_wrapper",
    "_gust_fiber_entry_wrapper:",
    "    mov x0, x20",
    "    blr x19",
    "    mov x0, x21",
    "    bl _gust_fiber_exit",
);

#[cfg(all(target_arch = "aarch64", not(target_vendor = "apple")))]
core::arch::global_asm!(
    ".text",
    ".global gust_fiber_entry_wrapper",
    "gust_fiber_entry_wrapper:",
    "    mov x0, x20",
    "    blr x19",
    "    mov x0, x21",
    "    bl gust_fiber_exit",
);
