# Native byte interface and qualification

`src/stdlib/native_bytes.gst` is an importable Gust module over the enrolled
zlib 1.3.2 adapter on `x86_64-unknown-linux-gnu`. It composes existing checked
Vectors, branded Arena indexes and call-region cleanup. It adds no compiler,
runtime, ABI, resource, move, drop or lifetime semantics.

The library patch owns the public FFI-R4 interface and its FFI-R5 regression
contribution. Full Phase26.1, final targeted compiler audit, R5/R6 and final-main
Historical qualification remain separate release gates. A library merge does
not close them or qualify distribution to installed compiler users.

## Public interface

```gust
func compress(ctx: &Arena, input: &std.Vector[byte, input_ctx], output_cap: int, level: int) BytesResult[ctx]
func decompress(ctx: &Arena, input: &std.Vector[byte, input_ctx], output_cap: int) BytesResult[ctx]
```

Both operations take a caller-chosen hard output capacity, from zero through
1 GiB inclusive in this first profile. Compression level follows the enrolled
adapter contract. Decompression never allocates from a stream's advertised
uncompressed size. Input and output brands are independent; the input Vector
and output Arena must remain live for their respective checked accesses.

Match the result through ordinary safe source:

- `Bytes { ticket }`: copy the bound ticket and use the output Arena's checked
  `get_ref` to obtain the completed `std.Vector[byte, ctx]`.
- `Error { code }`: classified failure, with no ticket field or partially
  published output. A zero-length Vector is a success variant, not an error.

`tests/stdlib_s26_1_roundtrip.gst` is the complete safe composition example:
compress, access its ticket, decompress those bytes, and check the original
content. The distinct-output fixture demonstrates independently live Arenas.
No unsafe block or raw address is needed in these consumers.

| Error code | Meaning |
| --- | --- |
| -1 | invalid arguments, including negative capacity or invalid level |
| -2 | range error, including capacity above this profile's 1 GiB bound |
| -3 | insufficient destination |
| -4 | corrupt or incomplete compressed data |
| -5 | native allocation or call-region acquisition failure |
| -6 | other native failure, including an impossible returned-count contradiction |

Call-region allocation uses -2 in its own runtime domain; the wrapper constructs
public -5 on failed acquisition instead of conflating it with adapter range.
The checked x86_64 Int/count/layout preconditions rule out the region's argument
and arithmetic failures on this path. Compiler-owned partial-allocation tests
are separate evidence; the public matrix does not claim to force allocator
exhaustion. Gust Arena exhaustion and invalid collection operations retain their
process-level abort/trap behavior, without an unwind/cleanup guarantee on traps.

## Reachable-path audit

| Path | Existing authority and library use |
| --- | --- |
| input creation/read | registered byte Vector constructors and checked indexing; caller proof retains the actual live backing/Arena, including admitted read-only local copies |
| output creation/growth | fresh Vector in ctx; checked zero-prefill and Clear establish capacity, then checked Push copies each accepted initialized byte |
| native addresses | only call-region-owned disjoint temporaries; Vector backing is never passed to native code or assumed pinned |
| acquired owner | existing linear opaque region and exact automatic cleanup; failed acquisition has no owner, later ordinary/error exits each clean up once |
| output acceptance | reject negative status and returned count beyond the actual capacity; AcceptResult/ReadOutput precede publication |
| output publication | completed copy-out, then one normal native-region cleanup, then ArenaAlloc/Set of the completed Vector and tagged Index construction |
| return/access | existing enum/Index representation, checked actual output-Arena substitution and get_ref; no native pointer acquires safe arena authority |

The small result constructors use internal enum tag/payload writes. The generic
compiler proof checks their actual layout, tag, payload, arguments and effects;
helper/type spellings are not authority. No callback or constructor allocation
is introduced. Implementation extern declarations retain explicit unsafe calls
and the enrolled package boundary; source declarations cannot enroll native code.

Merged compiler prerequisites are PR607 checked collections, PR609 production
trust, PR610 ticket publication, PR611 imported declarations, PR612 pure failure
and nested composition, and PR613 read-only input-copy history. The acceptance
baseline is merged `981caef41195601430c6dcaec0e06b2ca7ddb30f`. The checked support
handoff SHA256 is `fb62f1b4b24c26bd29d92ac7f544f30e9613be5add263a85f1ea00c168cb71bf`.
The maintained compiler contracts describe the closed caller/proof limits.
Arbitrary effects, general resource collections and new lifetime relations are
not admitted by this library; OD23 resource admission remains OPEN.

## Qualification and reproduction

Run `make gust`, then the full public guard with a reproduced approved package:

```sh
python3 scripts/stdlib_s26_1_native_bytes.py --package /path/to/approved/package
```

The Stdlib workflow reproduces all package inputs with the enrolled public
Ubuntu24.04 toolchain, requires the exact enrolled manifest, copies only the
existing public signature, and invokes that full command. The guard checks all
12 artifact hashes, stages a clean tool/package unit, verifies a physical offline
network namespace, compiles each relative-import consumer, runs its executable,
and rejects dynamic ELF dependencies. Production trust/snapshot verification
remains worker-owned; no private signing input or environment trust override is
used. No backend fallback is selected.

The normal guard requires 16 native cases: exact compressed bytes, exact decoded
bytes, empty compression, empty/nonempty zero destination, corrupt/truncated
streams, short compression/decompression, invalid level, negative/oversized
capacity, incompressible bytes, actual roundtrip, copied input and distinct Arenas.
Byte predicates explicitly convert their complete logical result to Int and
retain every byte equality. Success sentinels distinguish empty success from
an error. Three frontend negatives require their exact diagnostic and no output:
wrong-Arena access, requesting a ticket from Error, and output-Arena escape.
The optional source-negative mode is a manual focused check; CI uses the full
command and retains emitted sources, diagnostics and native executables.

Own local acceptance on the merged baseline passed all16 native cases plus3
rejections after fresh native rebuild and exact public package reproduction.
The receipt is
`/home/gust/phase26-recovery/stdlib-wrapper-20261023/merged-acceptance-v1/public/result.json`,
SHA256 `410a6220c549a2a4a88ef67c00a58eae517d0dab256f77ddaee83cf097c7e328`.
Publication requires complete compiler pin/registry validators, final exact-source
binding, resolved reviews and authoritative exact-head CI. Historical failed or
source-only attempts remain frozen under the same recovery root; none is counted
as passing public qualification. Compiler-owned registry rows are unchanged.

Final publication-byte qualification is retained at
`/home/gust/phase26-recovery/stdlib-wrapper-20261023/publication-qualification-v2/`;
its validators and public results bind all maintained file hashes. Exact-head
GitHub results and the actual merge are recorded in the checked final handoff.
The operational lane-state file is not a compiler byte authority; existing
roadmap projections remain enforced. No separate registry patch was required.
