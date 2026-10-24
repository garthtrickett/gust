# Phase26.2 — direct allocator invalidation with live owned resources

Canonical26.2C forbids freeing or moving an allocator while a branded resource
remains open. This increment qualifies direct Free, explicit allocator move,
and both operands of GenerationalSwap. Phase20/24 metadata opt-in, acquisition
identity, destructor registration, local ownership transfer, and cleanup plans
already exist; they are used rather than replaced.

Resource acquisitions and owned parameters retain their resolved owned type.
That type survives obligation snapshots/joins. Only resource acquisitions enter
the check: ordinary AST values, primitives and collection observations do not
become resource owners. A recursive metadata-driven walk follows owned struct
fields, checks resource brands against the existing canonical allocator
identity, and stops at references, pointers and Index observations. Alias and
aggregate carriage retain the same acquisition; spelling is not authority.
Pending ownership, deferred cleanup and a live/terminal join prevent direct
allocator invalidation. A consumed or transferred-out owner does not.

A generic owned call in defer schedules ownership instead of completing the
transfer at registration. The immediate invalidation check does not execute
when merely registering deferred Free: existing validated LIFO cleanup and
explicit consumption before that Free runs remain accepted. This increment
makes no general deferred allocator execution-order claim; that follow-on and
OD23 slot semantics remain OPEN. It does not close the full26.2 row.

## Qualification

`python3 scripts/phase26_2_allocator_guard.py` qualifies eleven exact shared
frontend refusals before backend selection and seven native positive controls.
The rejection driver is deliberately unavailable; unexpected acceptance cannot
link or execute a suspect invalidation. Success controls prove closed-owner
Free/move/swap, unrelated allocators, automatic cleanup and two valid deferred
Free orderings, including exact destructor output. Parameters, aliases, local
transfer, nested use, aggregate storage, deferred ownership and path joins are
covered. Result JSON binds source, compiler and ELF hashes; failed and partial
historical qualification is retained separately.

`python3 scripts/phase26_2_allocator_registration.py validate` and `inversions`
enforce exact additive enrollment against main35ebca4c. Frozen predecessors and
foreign rows remain unchanged; changed live bytes, projections and source pins
are independently checked. Operational lane-state prose is excluded only under
the existing nonempty-state requirement. Rollbacks, substituted coordinates,
foreign drift and unselected slot admission must still reject.

Publication additionally requires the complete affected-pin enumeration,
applicable Resource/arena regression guards, independent Standards/Spec review,
native emitted-object fixed point, exact-head owning CI and normal merge gates.
No new MIR meaning, ABI, runtime symbol, lifetime relationship, resource-valued
collection admission or deployment is introduced.
