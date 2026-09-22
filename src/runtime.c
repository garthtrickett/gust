#include "runtime/core_headers.h"
#include <errno.h>

/* Patch 25.5: five of the six remaining files moved to src/runtime-rs --
   arena, scratch, collections, file_io and host_io. They are NOT included
   here any more and they could not be: Patch 25.6 made the crate a single
   archive member, so linking against it for the tiny_host_* fixtures pulls
   in every ported function beside them. Keeping the C would have been 40+
   multiple-definition errors, which is why this deletion is the same
   commit as the port rather than a follow-up tidy.

   strings.c was the exception and is now gone too (Patch 25.10a). Patch
   25.5 sent its nine pure functions to Gust and checked in the emitted C,
   calling it what it was: a second seed. Patch 25.10 deletes the emitter,
   so that file's own header -- "edit the Gust and re-run the script" --
   would have named a script that cannot run. The native route still
   defers on compiler/runtime/strings.gst
   (capability=phase13_generic_source_to_mir), so the nine went to
   src/runtime-rs beside std_Clone_str and std_str_split, which were
   already there. compiler/runtime/strings.gst stays as the behavioural
   reference to compile when that capability lands. */
/* Patch 25.4: approved_scalar_imports.c moved to the Rust runtime crate
   src/runtime-rs (no_std then; Patch 25.6 dropped that when the scheduler
   followed). The tiny_host_* fixtures must stay FOREIGN -- a Gust
   rewrite would test Gust calling Gust and the contract would evaporate
   (O1) -- so they are linked from libgust_runtime_rs.a rather than
   included here. This unity build now covers seven files, not eight. */


