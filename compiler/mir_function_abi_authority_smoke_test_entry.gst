import "mir_function_abi_authority.gst" as abi;
import "mir_native_backend_abi_request.gst" as abi_request;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut table := abi.mir_function_abi_make_empty_table(
        "target:x86_64-unknown-linux-gnu",
        "x86_64-unknown-linux-gnu",
        &ctx
    );
    mut query := abi.mir_function_abi(
        table,
        "function:missing",
        "target:x86_64-unknown-linux-gnu",
        &ctx
    );
    if query.found != 0 { os.Exit(1); }
    os.LogStr("SUCCESS: Phase 16.1 function ABI authority smoke passed");
}
