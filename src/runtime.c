#include "runtime/core_headers.h"
#include <errno.h>

#include "runtime/arena.c"
#include "runtime/scratch.c"
/* Patch 25.6: fiber.c moved to src/runtime-rs. The unity build now covers
   six files; the scheduler arrives through the runtime archive. */
#include "runtime/collections.c"
#include "runtime/file_io.c"
#include "runtime/host_io.c"
#include "runtime/strings.c"
/* Patch 25.4: approved_scalar_imports.c moved to the Rust runtime crate
   src/runtime-rs (no_std then; Patch 25.6 dropped that when the scheduler
   followed). The tiny_host_* fixtures must stay FOREIGN -- a Gust
   rewrite would test Gust calling Gust and the contract would evaporate
   (O1) -- so they are linked from libgust_runtime_rs.a rather than
   included here. This unity build now covers seven files, not eight. */


