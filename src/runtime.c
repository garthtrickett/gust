#include "runtime/core_headers.h"
#include <errno.h>

/* Patch 25.5: five of the six remaining files moved to src/runtime-rs --
   arena, scratch, collections, file_io and host_io. They are NOT included
   here any more and they could not be: Patch 25.6 made the crate a single
   archive member, so linking against it for the tiny_host_* fixtures pulls
   in every ported function beside them. Keeping the C would have been 40+
   multiple-definition errors, which is why this deletion is the same
   commit as the port rather than a follow-up tidy.

   strings.c is the exception and stays for one more generation. Its nine
   remaining functions go to GUST, not Rust, so they arrive as emitted C
   inside this translation unit -- and the seed that builds gust_bootstrap
   does not contain them yet. See docs/PHASE25_ROADMAP.md for the ordering.
   Its other two, std_Clone_str and std_str_split, are already in the crate
   and are removed from it here for the same collision reason. */
#include "runtime/strings.c"
/* Patch 25.4: approved_scalar_imports.c moved to the Rust runtime crate
   src/runtime-rs (no_std then; Patch 25.6 dropped that when the scheduler
   followed). The tiny_host_* fixtures must stay FOREIGN -- a Gust
   rewrite would test Gust calling Gust and the contract would evaporate
   (O1) -- so they are linked from libgust_runtime_rs.a rather than
   included here. This unity build now covers seven files, not eight. */


