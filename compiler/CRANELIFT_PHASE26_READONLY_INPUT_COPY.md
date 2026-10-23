# Phase26.1 input-only local collection copies

This bounded compiler successor starts from merged composition support at
`0b5e3ad5dc832779aa8c76ed5d54a3f235bcb953`. It preserves existing collection
copy semantics, native lowering, brand rules and nonmoving Arena allocation.

A fresh local initialized by an exact same-type read of an already proved
collection may retain that collection's Create/backing/Arena history for input
borrowing. The source Arena must remain live. The copied binding cannot have
later collection operations; the existing copied-alias Append control retains
its initializer-stage rejection. The enclosing closed caller proof continues
to reject metadata writes, arbitrary effects, alternate dispatch, early Free,
field-derived storage and unproved control flow. This is no general reference
immutability guarantee or new lifetime relationship.

The scan and copied history consume the existing one-million-unit work budget.
There is no new balance, reset or larger limit. Source-produced canonical tests
check the actual copy and reject fabricated backing origins. The existing
metadata-write and copied-Append source regressions remain unchanged.

The production matrices exercise inferred and explicit copies, copy chains,
renaming, empty input, distinct live input/output Arenas and original-header
growth past capacity after the copy. Original backing remains in the live
nonmoving Arena; output still passes through disjoint native temporaries and
is published only after checked copy-out and cleanup. Mutation negatives test
copied Append/Clear, a mutated chained copy and forged copied metadata, alongside
all existing composition controls. Both ordinary and imported sources require
the unchanged signed production package, static deterministic linking and
physical offline execution.

Registration is additive. The predecessor registry, commands, deadlines,
operational-state retirement and protected text rows remain enforced, including
rollback and omission inversions. No MIR meaning, ABI, runtime symbol, resource,
move or drop semantics changes here. The Stdlib API remains separately owned.
Its own complete qualification/merge, exact wrapper audit, R5/R6 and Historical
Full on final merged main still gate Phase26.1 closure.
