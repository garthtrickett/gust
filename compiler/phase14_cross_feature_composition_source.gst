// Patch 14.12 route-level runtime sentinel.
//
// The registry-owned semantic case composes primitive and pointer-sized
// integers, conversions, pointers, stack slots, typed memory, strings/views,
// arrays/slices, structs, enums, joins, loop-carried values, and the selected
// nested aggregate relationships. Compiler-owned layout witnesses, rather
// than this scalar sentinel, remain authoritative for sizes and offsets.
func main() int {
    return 67;
}