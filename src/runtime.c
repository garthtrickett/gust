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
#include "runtime/approved_scalar_imports.c"


