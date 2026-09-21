#include "runtime/core_headers.h"
#include <errno.h>
#include "runtime/arena.c"
#include "runtime/scratch.c"
#include "runtime/fiber.c"
#include "runtime/collections.c"
#include "runtime/file_io.c"
#include "runtime/host_io.c"
#include "runtime/strings.c"
/* Patch 25.4: approved_scalar_imports.c moved to the no_std Rust crate
   src/runtime-rs. The tiny_host_* fixtures must stay FOREIGN -- a Gust
   rewrite would test Gust calling Gust and the contract would evaporate
   (O1) -- so they are linked from libgust_runtime_rs.a rather than
   included here. This unity build now covers seven files, not eight. */


