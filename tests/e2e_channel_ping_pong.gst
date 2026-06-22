type ChanArg[ctx] struct {
    in_chan: std.Channel[int, ctx],
    out_chan: std.Channel[int, ctx]
}
func worker_task(arg: *ChanArg[ctx]) {
    unsafe {
        mut val := (*arg).in_chan.Recv();
        (*arg).out_chan.Send(val + 100);
    }
}
func main() { 
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut in_c: std.Channel[int, ctx] := std.ChannelNew(ctx);
    mut out_c: std.Channel[int, ctx] := std.ChannelNew(ctx);

    mut arg: ChanArg[ctx];
    arg.in_chan = in_c;
    arg.out_chan = out_c;

    std.Spawn(worker_task, &arg);

    in_c.Send(42);
    mut result := out_c.Recv();

    os.LogInt(result);
}