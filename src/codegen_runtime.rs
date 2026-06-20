pub const CORE_HEADERS: &str = include_str!("runtime/core_headers.h");

pub const FIBER_RUNTIME: &str = include_str!("runtime/fiber.c");

pub const COLLECTIONS_RUNTIME: &str = include_str!("runtime/collections.c");

pub const SCRATCH_RUNTIME: &str = include_str!("runtime/scratch.c");

pub const ARENA_RUNTIME: &str = include_str!("runtime/arena.c");

pub const FILE_IO_RUNTIME: &str = include_str!("runtime/file_io.c");

pub const MOCK_PAYLOAD_RUNTIME: &str = include_str!("runtime/mock_payload.c");
