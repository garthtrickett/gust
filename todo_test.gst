type TodoItem[ctx] struct {
    id: int,
    title: str,
    completed: bool
}

type TodoList[ctx] struct {
    items: std.Vector[Index[TodoItem, ctx], ctx]
}

func add_todo(list: *TodoList[ctx], title: str, ctx: &Arena) {
    unsafe {
        mut item: Index[TodoItem, ctx] := os.ArenaAlloc(ctx) as Index[TodoItem, ctx];
        ctx[item].id = len((*list).items) + 1;
        ctx[item].title = std.Clone(ctx, title);
        ctx[item].completed = false;
        
        (*list).items.Push(item);
    }
}

func toggle_todo(list: *TodoList[ctx], id: int, ctx: &Arena) {
    unsafe {
        mut i := 0;
        while i < len((*list).items) {
            mut item := (*list).items[i];
            if ctx[item].id == id {
                if ctx[item].completed {
                    ctx[item].completed = false;
                } else {
                    ctx[item].completed = true;
                }
            }
            i = i + 1;
        }
    }
}

func print_todos(list: *TodoList[ctx], ctx: &Arena) {
    unsafe {
        os.LogStr("📋 --- My Todo List ---");
        mut i := 0;
        while i < len((*list).items) {
            mut item := (*list).items[i];
            mut status := " ";
            if ctx[item].completed {
                status = "X";
            }
            mut id_str := std.FormatInt(ctx[item].id);
            mut msg := std.Format("[ %s ] %s: %s", status, id_str, ctx[item].title);
            os.LogStr(msg);
            i = i + 1;
        }
        os.LogStr("-----------------------");
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut list: TodoList[ctx];
    list.items = std.VectorNew(ctx);

    add_todo(&list, "Learn Gust bootstrapping", ctx);
    add_todo(&list, "Celebrate successful v3 == v4", ctx);
    add_todo(&list, "Build something awesome", ctx);

    print_todos(&list, ctx);

    os.LogStr("⚙️  Completing task 2...");
    toggle_todo(&list, 2, ctx);

    print_todos(&list, ctx);
}
