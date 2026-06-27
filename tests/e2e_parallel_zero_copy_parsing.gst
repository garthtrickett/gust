type ASTNode struct {
    op: int,
    left_val: int,
    right_val: int
}
type ThreadArg[ctx] struct {
    file_ctx: Arena,
    out_chan: std.Channel[Arena, ctx]
}
func parser_thread(arg: *ThreadArg[ctx]) {
    unsafe { 
        mut file_ctx := move (*arg).file_ctx;
        
        mut node: Index[ASTNode, file_ctx] := os.ArenaAlloc(file_ctx);
        mut node_ref_parallel := file_ctx.get_ref(node);
        node_ref_parallel.op = 43;
        node_ref_parallel.left_val = 200;
        node_ref_parallel.right_val = 50;

        (*arg).out_chan.Send(move file_ctx);
    } 
}
func main() {
    mut main_ctx := os.Arena.New();
    defer main_ctx.Free();

    mut out_c: std.Channel[Arena, main_ctx] := std.ChannelNew(main_ctx);

    mut bg_ctx := os.Arena.New();

    mut arg: ThreadArg[main_ctx];
    arg.file_ctx = bg_ctx;
    arg.out_chan = out_c;

    std.Spawn(parser_thread, &arg);

    mut recv_ctx := out_c.Recv();
    defer recv_ctx.Free();

    mut node: Index[ASTNode, recv_ctx] := empty[Index[ASTNode, recv_ctx]];
    unsafe {
        node = 0 as Index[ASTNode, recv_ctx];
    }

    mut result := 0;
    if recv_ctx[node].op == 43 {
        result = recv_ctx[node].left_val + recv_ctx[node].right_val;
    }

    os.LogInt(result);
}
