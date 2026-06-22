type Packet struct {
    val: int
}
type StageArg[ctx] struct {
    in_chan: std.Channel[Arena, ctx],
    out_chan: std.Channel[Arena, ctx]
}
func stage_task(arg: *StageArg[ctx]) {
    unsafe {
        mut file_ctx := move (*arg).in_chan.Recv();
        mut node: Index[Packet, file_ctx] := 0 as Index[Packet, file_ctx];
        file_ctx[node].val = file_ctx[node].val + 100;
        (*arg).out_chan.Send(move file_ctx);
    }
}
func main() {
    mut main_ctx := os.Arena.New();
    defer main_ctx.Free();

    mut chan1: std.Channel[Arena, main_ctx] := std.ChannelNew(main_ctx);
    mut chan2: std.Channel[Arena, main_ctx] := std.ChannelNew(main_ctx);
    mut chan3: std.Channel[Arena, main_ctx] := std.ChannelNew(main_ctx);

    mut bg_ctx := os.Arena.New();
    mut node: Index[Packet, bg_ctx] := os.ArenaAlloc(bg_ctx);
    bg_ctx[node].val = 42;

    mut arg1: StageArg[main_ctx];
    arg1.in_chan = chan1;
    arg1.out_chan = chan2;

    mut arg2: StageArg[main_ctx];
    arg2.in_chan = chan2;
    arg2.out_chan = chan3;

    std.Spawn(stage_task, &arg1);
    std.Spawn(stage_task, &arg2);

    chan1.Send(move bg_ctx);

    mut final_ctx := chan3.Recv();
    defer final_ctx.Free();

    mut final_node: Index[Packet, final_ctx] := empty[Index[Packet, final_ctx]];
    unsafe {
        final_node = 0 as Index[Packet, final_ctx];
    }
    os.LogInt(final_ctx[final_node].val);
}