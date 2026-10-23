# Ordinary imported native byte boundaries

This successor starts at merged main `a695662da8805d89ac7b592227231a7fef98ec2a`.
It corrects routing and declaration identity for existing verified FFI contracts;
it introduces no MIR meaning, ABI, runtime symbol, resource or lifetime rule.

The legacy module-import preflight did not delegate fallible owned-out acquisition
or borrowed Byte spans. Its declaration lookup also concatenated a module prefix
onto runtime intrinsic names that typechecking had resolved globally. The same
identity mismatch existed in full-program FFI diagnostics and declarations.
Both paths now consume the typechecker's resolved identity. Ownership, exact
runtime-operation plans, span proof and signed package admission remain separate
requirements. An unregistered imported adapter still fails signed package
admission before object emission.

`phase26_ticket_publication_guard.py --imported` places the existing generic
compiler fixture's declarations and helper functions in an ordinary imported
module. It exercises all eleven native success/error cases, a deterministic
relink, rename invariance and eight source rejections in a physical offline
network namespace against the enrolled production package. The original
single-module guard and canonical fixture comparisons remain independently run.
This generated compiler fixture is not a substitute for the Stdlib public API.

The additive registration preserves the merged predecessor's public bytes and
projection objects, so a shallow runner requires no history fetch. It completes
the production successor's operational lane-state retirement in the ticket
successor's R4 text and record projections. The lane-state file must still exist
and be nonempty; its historical predecessor, membership, duplicate detection,
all non-operational rows, foreign rows and compiler byte pins remain checked.
Inversions cover rollback, protected-row substitution/omission/duplication,
missing/empty lane state and re-admitting the retired operational byte pin.
Frozen predecessor registry rows and evidence are unchanged.

The exact public wrapper remains unqualified at this boundary: its constant
error classification constructor and nested compression/decompression caller
require separately qualified compiler proofs. This patch does not accept that
API, close R4/R5/R6, or close Phase26.1. MIR-to-C oracle archives and their
retirement guards are unchanged; no fallback is introduced.
