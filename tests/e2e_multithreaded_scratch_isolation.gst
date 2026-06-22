type ThreadArg[ctx] struct {
    val: int,
    done: std.Channel[int, ctx]
}
func thread_task(arg: *ThreadArg[ctx]) {
    mut t_ctx := os.Arena.New();
    defer t_ctx.Free();
    os.SetThreadScratch(t_ctx);
    
    mut val := 0;
    unsafe {
        val = (*arg).val;
    }
    mut s := std.FormatInt(val);
    
    mut i := 0;
    while i < 20000 {
        i = i + 1;
    }
    
    mut s_parsed := std.parse_int(s);
    
    unsafe {
        (*arg).done.Send(s_parsed);
    }
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    
    mut c1: std.Channel[int, ctx] := std.ChannelNew(ctx);
    mut c2: std.Channel[int, ctx] := std.ChannelNew(ctx);
    
    mut arg1: ThreadArg[ctx];
    arg1.val = 42;
    arg1.done = c1;
    
    mut arg2: ThreadArg[ctx];
    arg2.val = 100;
    arg2.done = c2;
    
    std.Spawn(thread_task, &arg1);
    std.Spawn(thread_task, &arg2);
    
    mut res1 := c1.Recv();
    mut res2 := c2.Recv();
    
    os.LogInt(res1);
    os.LogInt(res2);
}