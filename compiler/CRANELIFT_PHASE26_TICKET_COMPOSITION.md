# Phase26.1 generic closed ticket composition

This compiler patch qualifies existing source semantics after imported native
byte-boundary support at `8acaa88f30da775c018dde38eea3800bda66c783`.
It does not select the Stdlib API or close Phase26.1.

A failure constructor still has one fresh local enum, its exact tag/payload
writes, and its exact local return. Its Int payload may now contain literals,
its Int status parameter, and bounded Int addition/subtraction. No call, alias,
Arena effect, allocation or reference can enter that expression. Success still
requires the exact supplied Index. Failed acquisition still passes the actual
Code local to the constructor; normalization does not substitute that argument.

A checked success arm copies its exact bound ticket and obtains its reference
from the actual live publication Arena. It may then make one proved scoped
producer call and end in another exhaustive ticket match. Only created backing
or an exact earlier published reference supplies input. Each continuation masks
shadowed parent provenance using lexical copies; nested blocks may reuse names.
The existing one-million-unit proof budget remains, scalar reads remain bounded,
failure expressions allow at most 4096 distinct nodes, and composition allows at
most 64 nested matches. No arbitrary caller control flow is admitted.

An ordinary module may contain a fully proved producer that the entry does not
call. Defined functions have Local linkage, and every body is still scanned for
address escape and alternate dispatch. Any actual caller disconnected from entry
still rejects; a zero-caller producer does not acquire a fabricated actual
storage history. Orphan collection operations still reject.

The generic source fixture tests two and three native calls, lexical name reuse,
renaming, an unused sibling producer, short second output, and pure failure
classification. The deterministic constructor probe deliberately maps an adapter
error to -5 to exercise pure construction on the static production link path;
that fixture does not define the public error policy. Source negatives retain
all predecessor controls and add disconnected callers, aliases/effects after
borrowing, constructor calls and substituted acquisition status. Canonical
mutations independently check exact publication provenance and error arguments.

Both single-module and ordinary-import matrices use the unchanged enrolled
production identity, epochs, validity window and exact signed artifact closure.
They require static executables, deterministic linking, physical offline
execution, and rejection before execution for negative cases. Existing ticket
and imported matrices remain required. No guard deadline, resource budget,
production trust authority, runtime symbol, MIR meaning, ABI or resource/lifetime
semantics changes here.

The public wrapper still needs its separately owned merged patch and targeted
Vector/Arena audit. R5/R6 and Historical Full on exact final merged main remain
required before Phase26.1 closes.
